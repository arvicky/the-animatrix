import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

/// 对话消息
class ChatMessage {
  final String role; // 'user' | 'assistant'
  final String text;
  final bool streaming; // 是否仍在流式输出中
  final String? audioBase64; // assistant 的 TTS 语音（base64），非空 = 语音消息
  final bool spoken; // 是否已自动播报过（每条回复只自动播一遍）
  const ChatMessage(
      {required this.role,
      required this.text,
      this.streaming = false,
      this.audioBase64,
      this.spoken = false});

  ChatMessage copyWith(
          {String? text, bool? streaming, String? audioBase64, bool? spoken}) =>
      ChatMessage(
        role: role,
        text: text ?? this.text,
        streaming: streaming ?? this.streaming,
        audioBase64: audioBase64 ?? this.audioBase64,
        spoken: spoken ?? this.spoken,
      );
}

/// 对话服务 —— 通过 WebSocket JSON-RPC 连接 hermes serve（全局单例）。
///
/// 协议（已实测验证）：
///   session.create → session_id
///   prompt.submit {session_id, text} → 异步流式事件
///   事件帧 method=event, params.type ∈ {message.start, thinking.delta,
///     message.delta, message.complete}
///
/// 热会话复用：单例持有 session_id，页面切换/重建不新建会话，
/// 第二次对话起不再冷启动 agent，回复显著变快。
class ConversationService {
  ConversationService._();

  /// 全局单例 —— 会话跨页面复用
  static final ConversationService instance = ConversationService._();

  static const String url =
      'ws://127.0.0.1:9119/api/ws?token=exobrain-local-2026';

  /// 当前连接的外脑 URL（可切换档案）
  String _currentUrl = url;

  /// 会话模型 —— 与微信端同款（deepseek-v4-pro），保证回复智能程度一致。
  static const String sessionModel = 'deepseek-v4-pro';
  static const String sessionProvider = 'deepseek';

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  String? _sessionId;
  int _nextId = 1;

  /// 待完成的 RPC 回调：id → 处理函数
  final Map<int, void Function(dynamic raw)> _handlers = {};
  /// 当前活跃的消息流控制器
  StreamController<ChatMessage>? _activeStream;

  /// 语音转写事件流：serve voice.record 录音 → 讯飞转写 → 推送文字
  final StreamController<String> voiceTranscripts =
      StreamController<String>.broadcast();

  /// 连接状态变化流（true=已连接，false=断线），供页面同步连接态并自动重连
  final StreamController<bool> _connCtrl = StreamController<bool>.broadcast();
  Stream<bool> get connectionChanges => _connCtrl.stream;

  bool _connecting = false;

  bool get connected => _channel != null && _sessionId != null;
  String? get sessionId => _sessionId;

  /// 连接（幂等）：已连接直接返回；连接中等待；否则新建 WebSocket + 会话。
  Future<void> connect() async {
    if (connected) return;
    while (_connecting) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (connected) return;
    }
    _connecting = true;
    try {
      final ch = WebSocketChannel.connect(Uri.parse(_currentUrl));
      await ch.ready;
      _channel = ch;
      _sub = ch.stream.listen(_dispatch, onError: (_) {}, onDone: _onDone);
      final sid = await _createSession();
      _sessionId = sid;
      _connCtrl.add(true);
    } finally {
      _connecting = false;
    }
  }

  /// 断线重连（保留原 session_id，若后端会话仍热则秒连）
  Future<void> reconnect() async {
    _onDone();
    await connect();
  }

  /// 切换到另一个外脑档案：断开当前连接，连新 URL 并重建会话。
  Future<void> switchTo(String newUrl) async {
    if (newUrl == _currentUrl && connected) return;
    _currentUrl = newUrl;
    _onDone();
    await connect();
  }

  Future<String> _createSession() {
    final id = _nextId++;
    final completer = Completer<String>();
    _handlers[id] = (raw) {
      final msg = _tryDecode(raw);
      if (msg != null && msg['id'] == id) {
        _handlers.remove(id);
        completer.complete(msg['result']['session_id'] as String);
      }
    };
    _channel!.sink.add(jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'method': 'session.create',
      'params': {
        'title': '外脑对话',
        'model': sessionModel,
        'provider': sessionProvider,
      },
    }));
    return completer.future.timeout(const Duration(seconds: 15));
  }

  /// 发送用户消息，返回 assistant 消息流（最后一条 streaming=false 表示完成）。
  Stream<ChatMessage> send(String text) {
    final controller = StreamController<ChatMessage>();
    if (!connected) {
      // 自动重连一次
      connect().then((_) {
        if (!connected) {
          controller.addError(StateError('未连接'));
          controller.close();
        }
      });
      // 等待连接完成后再真正发送
      _sendWhenReady(controller, text);
      return controller.stream;
    }
    _doSend(controller, text);
    return controller.stream;
  }

  /// 开启语音模式 + TTS 播报（复用 serve 桌面语音：麦克风/喇叭在电脑上）。
  Future<bool> voiceEnable() async {
    if (!connected) return false;
    final on = await _voiceToggle('on');
    if (!on) return false;
    await _voiceToggle('tts'); // 开启回复自动 TTS 播报
    return true;
  }

  Future<bool> _voiceToggle(String action) async {
    final id = _nextId++;
    final completer = Completer<bool>();
    _handlers[id] = (raw) {
      final msg = _tryDecode(raw);
      if (msg != null && msg['id'] == id) {
        _handlers.remove(id);
        final result = msg['result'] ?? {};
        completer.complete(result['enabled'] == true);
      }
    };
    _channel!.sink.add(jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'method': 'voice.toggle',
      'params': {'action': action},
    }));
    return completer.future
        .timeout(const Duration(seconds: 10), onTimeout: () => false);
  }

  /// 开始 VAD 录音（静音自动停，转写后推 voice.transcript 事件）。
  Future<bool> voiceRecordStart() async {
    if (!connected) return false;
    final id = _nextId++;
    final completer = Completer<bool>();
    _handlers[id] = (raw) {
      final msg = _tryDecode(raw);
      if (msg != null && msg['id'] == id) {
        _handlers.remove(id);
        final status = (msg['result'] ?? {})['status'];
        completer.complete(status == 'recording');
      }
    };
    _channel!.sink.add(jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'method': 'voice.record',
      'params': {'action': 'start', 'session_id': _sessionId},
    }));
    return completer.future
        .timeout(const Duration(seconds: 10), onTimeout: () => false);
  }

  /// 停止录音并强制转写。
  Future<void> voiceRecordStop() async {
    if (!connected) return;
    final id = _nextId++;
    _handlers[id] = (raw) {
      final msg = _tryDecode(raw);
      if (msg != null && msg['id'] == id) _handlers.remove(id);
    };
    _channel!.sink.add(jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'method': 'voice.record',
      'params': {'action': 'stop', 'session_id': _sessionId},
    }));
  }

  /// 文字合成语音（TTS，MiniMax），返回音频 base64（App 内播放用）。
  Future<String?> ttsSynthesize(String text) async {
    if (!connected) return null;
    final id = _nextId++;
    final completer = Completer<String?>();
    _handlers[id] = (raw) {
      final msg = _tryDecode(raw);
      if (msg != null && msg['id'] == id) {
        _handlers.remove(id);
        final result = msg['result'] ?? {};
        completer.complete(result['audio_base64'] as String?);
      }
    };
    _channel!.sink.add(jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'method': 'tts.synthesize',
      'params': {'text': text},
    }));
    return completer.future
        .timeout(const Duration(seconds: 30), onTimeout: () => null);
  }

  /// 音频转文字（STT，faster-whisper），返回转写文字。
  Future<String> sttTranscribe(String audioBase64, {String format = 'webm'}) async {
    if (!connected) return '';
    final id = _nextId++;
    final completer = Completer<String>();
    _handlers[id] = (raw) {
      final msg = _tryDecode(raw);
      if (msg != null && msg['id'] == id) {
        _handlers.remove(id);
        final result = msg['result'] ?? {};
        completer.complete((result['transcript'] ?? '').toString());
      }
    };
    _channel!.sink.add(jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'method': 'stt.transcribe',
      'params': {'audio_base64': audioBase64, 'format': format},
    }));
    return completer.future
        .timeout(const Duration(seconds: 60), onTimeout: () => '');
  }

  Future<void> _sendWhenReady(
      StreamController<ChatMessage> controller, String text) async {
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (!connected && DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 150));
    }
    if (!connected) {
      if (!controller.isClosed) {
        controller.addError(StateError('连接超时'));
        controller.close();
      }
      return;
    }
    _doSend(controller, text);
  }

  void _doSend(StreamController<ChatMessage> controller, String text) {
    var assistantText = '';
    final id = _nextId++;

    _handlers[id] = (raw) {
      final msg = _tryDecode(raw);
      if (msg == null) return;
      if (msg['method'] != 'event') return;
      final params = msg['params'] ?? {};
      final type = params['type'];
      final payload = params['payload'] ?? {};
      switch (type) {
        case 'message.start':
          // 等待期反馈：不立即发空消息（保留 App 端的「收到，稍等」提示）
          break;
        case 'message.delta':
          assistantText += (payload['text'] ?? '').toString();
          controller.add(
              ChatMessage(role: 'assistant', text: assistantText, streaming: true));
          break;
        case 'message.complete':
          final full = (payload['text'] ?? '').toString();
          if (full.isNotEmpty) assistantText = full;
          controller.add(
              ChatMessage(role: 'assistant', text: assistantText, streaming: false));
          _handlers.remove(id);
          _activeStream = null;
          controller.close();
          break;
      }
    };

    _activeStream = controller;
    _channel!.sink.add(jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'method': 'prompt.submit',
      'params': {'session_id': _sessionId, 'text': text},
    }));
  }

  void _dispatch(dynamic raw) {
    // 识别语音转写事件（serve voice.record → 讯飞转写 → voice.transcript）
    final msg = _tryDecode(raw);
    if (msg != null && msg['method'] == 'event') {
      final params = msg['params'] ?? {};
      if (params['type'] == 'voice.transcript') {
        final payload = params['payload'] ?? {};
        final text = (payload['text'] ?? '').toString();
        if (text.isNotEmpty && !voiceTranscripts.isClosed) {
          voiceTranscripts.add(text);
        }
      }
    }
    for (final fn in _handlers.values.toList()) {
      fn(raw);
    }
  }

  void _onDone() {
    _channel = null;
    _sessionId = null;
    _activeStream?.close();
    _activeStream = null;
    _connCtrl.add(false);
  }

  dynamic _tryDecode(dynamic raw) {
    try {
      return jsonDecode(raw as String);
    } catch (_) {
      return null;
    }
  }

  /// 注意：全局单例不建议 dispose；仅测试/极端场景调用。
  void dispose() {
    _sub?.cancel();
    _handlers.clear();
    _activeStream?.close();
    _activeStream = null;
    _channel?.sink.close();
    _channel = null;
    _sessionId = null;
  }
}
