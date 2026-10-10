import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';

import '../services/audio_utils.dart';
import '../services/conversation_service.dart';
import '../data/memory_repository.dart';
import '../models/memory_card.dart';

/// 意识体状态机：待机 → 聆听 → 思考 → 说话
enum BrainState { idle, listening, thinking, speaking }

/// 可对话的外脑节点（外脑矩阵）
class ExobrainPeer {
  final String name; // 外脑名
  final String owner; // 主人名
  final String profile; // Hermes 档案名（代答 target）
  final Color color; // 主题色
  final bool isSelf;
  const ExobrainPeer({
    required this.name,
    required this.owner,
    required this.color,
    this.profile = '',
    this.isSelf = false,
  });
}

/// 外脑档案（可切换「登录」的 Hermes 档案），区别于「交互外脑」。
class ExobrainProfile {
  final String name; // 显示名（主人名）
  final String profile; // Hermes 档案名
  final String url; // serve WebSocket URL（固定端口 + token）
  final Color color;
  const ExobrainProfile({
    required this.name,
    required this.profile,
    required this.url,
    required this.color,
  });
}

/// 「对话」tab —— 意识体主交互页。
/// 光球动效 + 点击唤起 + 真实对话（WebSocket 连 hermes serve）。
class ConsciousnessPage extends StatefulWidget {
  const ConsciousnessPage({super.key});

  @override
  State<ConsciousnessPage> createState() => _ConsciousnessPageState();
}

class _ConsciousnessPageState extends State<ConsciousnessPage>
    with TickerProviderStateMixin {
  late final AnimationController _breathe;
  late final AnimationController _pulse;

  BrainState _state = BrainState.idle;
  Timer? _memoryCycle;
  int _memoryIndex = 0;

  final ConversationService _service = ConversationService.instance;
  bool _connecting = false;
  bool _connected = false;

  final List<ChatMessage> _messages = [];
  final TextEditingController _input = TextEditingController();
  bool _inChat = false; // 是否已进入聊天界面（点光球后为 true，不发消息）
  bool _sending = false;
  bool _recording = false;
  bool _playing = false; // 是否正在播放语音（与录音互斥）
  bool _callMode = false; // 通话模式（持续语音循环：播完自动听，开口打断继续）

  // 语音（方案 B：App 内录音 + 播放）—— 懒加载，避免测试环境触发平台通道
  AudioRecorder? _recorder;
  AudioPlayer? _player;
  AudioRecorder get _rec => _recorder ??= AudioRecorder();
  AudioPlayer get _play => _player ??= AudioPlayer();
  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  double _amplitude = 0.0; // 音量 0..1
  StreamSubscription<Amplitude>? _ampSub;
  StreamSubscription<bool>? _connSub; // 连接状态监听（断线自动重连）

  // 流式 TTS 分段播报（阶段1：边收 delta 边按句合成播）
  int _ttsGen = 0; // 轮次令牌：打断/新一轮后旧任务自动跳过
  Future<void> _ttsChain = Future.value(); // 串行播放链（保证句子顺序）
  String _ttsBuffer = '';
  bool _interrupted = false; // 本轮对话是否被打断（停止后续 TTS）

  // VAD 自动断句（阶段2：静音自动停）
  int _silentMs = 0;

  // 播放中开口打断监听（阶段2：播放时监听麦克风，检测人声打断）
  StreamSubscription<Amplitude>? _interruptAmpSub;
  bool _interruptWatching = false;
  int _interruptSpeechMs = 0;

  /// 外脑矩阵：可对话的外脑节点
  static const _peers = [
    ExobrainPeer(
        name: '曲炳阳', owner: '我', color: Color(0xFF00D4FF), isSelf: true),
    ExobrainPeer(name: '小梦', owner: '王一如', color: Color(0xFFB18CFF), profile: 'matrix-wang'),
    ExobrainPeer(name: 'neo', owner: 'Neo', color: Color(0xFF00E5A0), profile: 'neo-animatrix'),
  ];
  int _activePeer = 0;

  /// 可切换「登录」的外脑档案（Hermes 多档案，固定端口 + token）
  static const _profiles = [
    ExobrainProfile(
        name: '曲炳阳',
        profile: 'animatrix',
        url: 'ws://127.0.0.1:9119/api/ws?token=exobrain-local-2026',
        color: Color(0xFF00D4FF)),
    ExobrainProfile(
        name: '王一如',
        profile: 'matrix-wang',
        url: 'ws://127.0.0.1:9120/api/ws?token=exobrain-wang-2026',
        color: Color(0xFFB18CFF)),
    ExobrainProfile(
        name: 'neo',
        profile: 'neo-animatrix',
        url: 'ws://127.0.0.1:9121/api/ws?token=exobrain-neo-2026',
        color: Color(0xFF00E5A0)),
  ];
  int _activeProfile = 0; // 当前登录的外脑档案索引

  // 聊天视图：0=我的对话（我和我的外脑），1=互联对话（别人和我的外脑）
  int _viewMode = 0;
  final _repository = ServerRepository();
  List<MemoryCard> _interlinkCards = []; // 互联对话记录（交互存档）

  static const _memories = [
    '我记得你爱喝金宾，做成嗨棒挺配烧鸟',
    '你常去杭州庆春路那家和炙烧鸟，肖悦乐乐带你去的',
    '你喜欢逛古着店，挑稀奇古怪的配饰和衣服',
    '《NANA》你看了六七遍，影响很深',
    '你爱打羽毛球',
    '你喜欢韩料，尤其铁板鸡',
  ];

  @override
  void initState() {
    super.initState();
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
    _memoryCycle = Timer.periodic(
      const Duration(seconds: 5),
      (_) => setState(
        () => _memoryIndex = (_memoryIndex + 1) % _memories.length,
      ),
    );
    if (kIsWeb) _connect();
    _loadInterlink();
    // 监听连接状态变化：断线时同步状态并自动重连
    _connSub = _service.connectionChanges.listen((ok) {
      if (!mounted) return;
      if (ok) {
        setState(() {
          _connected = true;
          _connecting = false;
        });
      } else {
        setState(() => _connected = false);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && !_connected) _connect();
        });
      }
    });
  }

  /// 加载互联对话记录（别人和我的外脑的交互存档）
  Future<void> _loadInterlink() async {
    try {
      final cards = await _repository.fetchCards();
      if (!mounted) return;
      setState(() {
        _interlinkCards = cards
            .where((c) =>
                c.tags.contains('外脑互联') || c.tags.contains('交互存档'))
            .toList();
      });
    } catch (_) {}
  }

  /// 发送代答请求 + 轮询对方外脑的回传
  Future<void> _sendInterlink(ExobrainPeer peer, String text) async {
    try {
      await _repository.askInterlink(peer.profile, text);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final idx = _messages.lastIndexWhere((m) => m.role == 'assistant' && m.streaming);
        final err = ChatMessage(role: 'assistant', text: '发送失败：$e');
        if (idx != -1) {
          _messages[idx] = err;
        } else {
          _messages.add(err);
        }
      });
      return;
    }
    _pollInterlinkReply(peer);
  }

  /// 轮询代答结果（最多 2 分钟），有新交互存档就取最新一条作为代答回复
  void _pollInterlinkReply(ExobrainPeer peer) {
    final before = _interlinkCards.length;
    var tries = 0;
    Timer.periodic(const Duration(seconds: 5), (timer) async {
      tries++;
      if (tries > 24) {
        timer.cancel();
        if (!mounted) return;
        setState(() {
          final idx = _messages.lastIndexWhere((m) => m.role == 'assistant' && m.streaming);
          final msg = ChatMessage(
              role: 'assistant',
              text: '「${peer.name}」暂时没回传，稍后可在「互联对话」里查看。');
          if (idx != -1) _messages[idx] = msg;
        });
        return;
      }
      await _loadInterlink();
      if (!mounted) return;
      if (_interlinkCards.length > before) {
        timer.cancel();
        final latest = _interlinkCards.last;
        final text = latest.summary.isNotEmpty ? latest.summary : latest.content;
        setState(() {
          final idx = _messages.lastIndexWhere((m) => m.role == 'assistant' && m.streaming);
          final reply = ChatMessage(role: 'assistant', text: '「${peer.name}」代答：$text');
          if (idx != -1) {
            _messages[idx] = reply;
          } else {
            _messages.add(reply);
          }
        });
      }
    });
  }

  Future<void> _connect() async {
    if (_connected || _connecting) return;
    setState(() => _connecting = true);
    try {
      await _service.connect();
      if (mounted) setState(() => _connected = true);
    } catch (_) {
      if (mounted) setState(() => _connecting = false);
    }
  }

  /// 切换到另一个外脑档案（登录档案），并重置对话。
  Future<void> _switchProfile(int index) async {
    if (index == _activeProfile) return;
    setState(() {
      _activeProfile = index;
      _connected = false;
      _connecting = true;
      _messages.clear();
      _activePeer = 0; // 交互对象重置为「自己」
      _state = BrainState.idle;
    });
    try {
      await _service.switchTo(_profiles[index].url);
      // 连接成功后 connectionChanges 监听会 setState _connected = true
    } catch (_) {
      if (mounted) setState(() => _connecting = false);
    }
  }

  /// 弹出外脑切换选择器（bottom sheet）
  void _showProfileSwitcher() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0E1B3D),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('切换外脑（登录档案）',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFEAF0FF))),
            ),
            for (var i = 0; i < _profiles.length; i++)
              ListTile(
                leading: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, color: _profiles[i].color),
                ),
                title: Text(_profiles[i].name,
                    style: TextStyle(
                        fontSize: 14,
                        color: i == _activeProfile
                            ? _profiles[i].color
                            : const Color(0xFFD6E2FF))),
                subtitle: Text(_profiles[i].profile,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF6B7794))),
                trailing: i == _activeProfile
                    ? const Icon(Icons.check,
                        size: 18, color: Color(0xFF00E5A0))
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  _switchProfile(i);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// 点击光球：进入聊天界面（不发消息），唤起外脑走一遍状态
  void _onOrbTap() {
    setState(() {
      _inChat = true;
      _state = BrainState.listening;
    });
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() => _state = BrainState.thinking);
    });
    Future.delayed(const Duration(milliseconds: 2800), () {
      if (!mounted) return;
      setState(() => _state = BrainState.speaking);
    });
    Future.delayed(const Duration(milliseconds: 4600), () {
      if (!mounted) return;
      setState(() => _state = BrainState.idle);
    });
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty || _sending || !_connected) return;
    _unlockAudio(); // 用户手势：解锁浏览器自动播放
    // 用户再次输入：停止当前播报（旧回复不再自动重播）
    if (_playing) await _stopPlayback();
    // 新一轮对话：作废旧 TTS 链任务 + 重置缓冲
    _ttsGen++;
    _interrupted = false;
    _ttsBuffer = '';
    int ttsLen = 0; // 已入队 TTS 的字符数（跟踪 delta 增量）
    var trimmed = text.trim();

    // 语音/文字触发路由：识别「找XX」「跟XX说XX」「问XX」
    final routed = _matchPeerRoute(trimmed);
    if (routed != null) {
      final peerIndex = routed.$1;
      final rest = routed.$2;
      setState(() {
        if (peerIndex != _activePeer) {
          _activePeer = peerIndex;
          _messages.clear();
        }
        _messages.add(ChatMessage(
            role: 'assistant',
            text: '已切换：与「${_peers[peerIndex].name}」对话'));
      });
      if (rest.isEmpty) return;
      trimmed = rest;
    }

    // 非自己外脑：实时直连对方外脑 serve（经 memory_server 代理 + 授权检查）
    if (!_peers[_activePeer].isSelf) {
      final peer = _peers[_activePeer];
      final targetUrl = 'ws://127.0.0.1:9118/api/ws?target=${peer.profile}';
      try {
        await _service.switchTo(targetUrl);
      } catch (_) {
        if (mounted) {
          setState(() {
            _messages.add(ChatMessage(role: 'user', text: trimmed));
            _messages.add(ChatMessage(
                role: 'assistant',
                text: '「${peer.name}」连接失败（可能未授权或不在线）'));
            _sending = false;
            _state = BrainState.idle;
          });
        }
        _input.clear();
        return;
      }
    }

    setState(() {
      _messages.add(ChatMessage(role: 'user', text: trimmed));
      // 等待期即时反馈：先回一句「收到，稍等」，流式回复到来时自动替换
      _messages.add(ChatMessage(
          role: 'assistant', text: '收到你的消息，稍等我分析一下…', streaming: true));
      _sending = true;
      _state = BrainState.listening;
    });
    _input.clear();

    try {
      await for (final msg in _service.send(trimmed)) {
        if (!mounted) break;
        // 流式 TTS：把新增文本切句入队（边生成边播）
        if (msg.role == 'assistant' && msg.streaming && !_interrupted) {
          final full = msg.text;
          if (full.length > ttsLen) {
            _feedTts(full.substring(ttsLen));
            ttsLen = full.length;
          }
        }
        setState(() {
          _state = msg.streaming ? BrainState.thinking : BrainState.speaking;
          // 找到或追加当前 assistant 流式消息
          final idx = _messages.lastIndexWhere((m) => m.role == 'assistant' && m.streaming);
          if (msg.role == 'assistant') {
            if (msg.streaming) {
              if (idx == -1) {
                _messages.add(msg);
              } else {
                _messages[idx] = msg;
              }
            } else {
              // 完成：把最后一个流式 assistant 替换为最终版
              if (idx != -1) {
                _messages[idx] = msg;
              } else {
                _messages.add(msg);
              }
            }
          }
        });
      }
    } catch (_) {
      // 忽略发送错误
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          _state = BrainState.idle;
          // 清理残留的等待提示（流式回复未到达时去掉光标）
          final idx = _messages
              .lastIndexWhere((m) => m.role == 'assistant' && m.streaming);
          if (idx >= 0) {
            _messages[idx] = _messages[idx].copyWith(streaming: false);
          }
        });
      }
    }
    // 回复完成后：flush 剩余 TTS buffer（最后一句可能无标点）
    if (!_interrupted && _ttsBuffer.trim().isNotEmpty) {
      _enqueueTts(_ttsBuffer);
      _ttsBuffer = '';
    }
  }

  /// 停止当前播放（打断 TTS 播报）
  Future<void> _playAudio(String audioBase64) async {
    if (_recording) return; // 录音中不播放
    if (mounted) setState(() => _playing = true);
    // 打电话模式才监听麦克风（开口打断+自动循环）；默认对讲机模式录音由用户手动按键触发
    if (_callMode) {
      await _startInterruptWatch();
    }
    // 等播放真正结束（自然 completed 或被打断的 stopped）再返回 → 不截断、也不卡死打断后的链
    final completer = Completer<void>();
    final sub = _play.onPlayerStateChanged.listen((state) {
      if (state != PlayerState.completed && state != PlayerState.stopped) return;
      if (mounted) setState(() => _playing = false);
      _stopInterruptWatch(); // 播放完/被停，停止监听
      // 通话模式：播完自动进入下一轮录音（持续通话循环）
      if (_callMode && mounted && !_recording) {
        _startRecording();
      }
      if (!completer.isCompleted) completer.complete();
    });
    try {
      await _play.play(
          BytesSource(base64Decode(audioBase64), mimeType: 'audio/mpeg'));
      debugPrint('[TTS] play ok');
    } catch (e) {
      debugPrint('[TTS] play failed: $e');
      if (mounted) setState(() => _playing = false);
      if (!completer.isCompleted) completer.complete();
    }
    await completer.future; // 等播放完成
    await sub.cancel();
  }

  /// 解锁浏览器自动播放（autoplay policy）：须在用户手势回调里调用。
  Future<void> _unlockAudio() async {
    try {
      await _play.resume();
    } catch (_) {}
  }

  /// 语音按钮：点击开始/停止录音。
  /// 点开录音时强制打断终止外脑播放（作废 TTS 链 + 停播 + 通知 serve 停生成），只有我能说话。
  Future<void> _toggleRecording() async {
    if (!_connected || _sending) return;
    if (_recording) {
      await _stopRecording();
      return;
    }
    // 点录音：立即标记「收录中」，彻底静音（停播 + 作废待播 + 通知 serve 停生成），绝不播上一轮
    _recording = true;
    await _interrupt();
    await _stopInterruptWatch();
    await _startRecording();
  }

  /// 通话模式开关：进入自动开始第一轮录音，退出停止录音/播放。
  Future<void> _toggleCallMode() async {
    if (_callMode) {
      // 挂断：退出通话模式
      setState(() => _callMode = false);
      await _stopInterruptWatch();
      if (_recording) await _stopRecording();
      await _stopPlayback();
    } else {
      // 接通：进入通话模式，自动开始听
      if (!_connected || _sending) return;
      setState(() => _callMode = true);
      if (_playing) await _stopPlayback();
      await _stopInterruptWatch();
      if (!_recording) await _startRecording();
    }
  }

  /// 停止当前播放（打断 TTS 播报）
  Future<void> _stopPlayback() async {
    try {
      await _play.stop();
    } catch (_) {}
    if (mounted) setState(() => _playing = false);
  }

  /// 打断：停止播报 + 通知 serve 停生成 + 清空待播队列
  Future<void> _interrupt() async {
    _interrupted = true;
    _ttsGen++;
    _ttsChain = Future.value(); // 彻底清空待播链
    _ttsBuffer = '';
    await _stopPlayback();
    await _service.interrupt();
  }

  /// 把一句话追加到串行播放链（顺序播，不阻塞 delta 接收）。
  void _enqueueTts(String sentence) {
    final s = sentence.trim();
    if (s.isEmpty) return;
    final gen = _ttsGen; // 捕获当前轮次
    _ttsChain = _ttsChain.then((_) async {
      if (_interrupted || gen != _ttsGen || !mounted) return;
      final b64 = await _service.ttsSynthesize(s);
      if (b64 == null || !mounted || _interrupted || gen != _ttsGen) return;
      await _playAudio(b64);
    });
  }

  /// 累积流式文本，切完整句（标点结尾）入队。语音播完整内容，与文字回复一致。
  void _feedTts(String newText) {
    _ttsBuffer += newText;
    final re = RegExp(r'[^。！？；…\n]+[。！？；…]');
    while (true) {
      final m = re.firstMatch(_ttsBuffer);
      if (m == null) break;
      _enqueueTts(m.group(0)!);
      _ttsBuffer = _ttsBuffer.substring(m.end);
    }
  }

  /// 播放中监听麦克风：检测到持续人声 → 开口打断（进入下一轮录音）。
  Future<void> _startInterruptWatch() async {
    if (_interruptWatching || _recording) return;
    try {
      await _rec.start(const RecordConfig(), path: '');
      _interruptWatching = true;
      _interruptSpeechMs = 0;
      _interruptAmpSub = _rec
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen((amp) {
        if (!mounted || !_playing) return;
        final v = ((amp.current + 60) / 60).clamp(0.0, 1.0).toDouble();
        // 播放中用更高阈值（0.35），区分近场人声与喇叭回声
        if (v > 0.35) {
          _interruptSpeechMs += 100;
          if (_interruptSpeechMs >= 300) {
            _interruptSpeechMs = 0;
            _onVoiceInterrupt();
          }
        } else {
          _interruptSpeechMs = 0;
        }
      });
    } catch (_) {}
  }

  Future<void> _stopInterruptWatch() async {
    if (!_interruptWatching) return; // 没在监听就不动（幂等）
    _interruptWatching = false;
    await _interruptAmpSub?.cancel();
    _interruptAmpSub = null;
    try {
      await _rec.stop();
    } catch (_) {}
  }

  /// 播放中被开口打断：停播 + 打断 serve → 立即进入录音继续听。
  Future<void> _onVoiceInterrupt() async {
    await _interrupt();
    await _stopInterruptWatch();
    if (mounted && !_recording) await _startRecording();
  }

  Future<void> _startRecording() async {
    _unlockAudio(); // 用户手势：解锁浏览器自动播放
    try {
      if (!await _rec.hasPermission()) {
        return; // 无麦克风权限
      }
      setState(() {
        _recording = true;
        _recordingSeconds = 0;
        _amplitude = 0;
        _state = BrainState.listening;
      });
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordingSeconds++);
      });
      _silentMs = 0;
      _ampSub = _rec
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen((amp) {
        if (!mounted) return;
        final v = ((amp.current + 60) / 60).clamp(0.0, 1.0).toDouble();
        setState(() => _amplitude = v);
        // VAD 自动断句：音量高=说话，连续静音 500ms=说完自动停
        if (v > 0.12) {
          _silentMs = 0;
        } else {
          _silentMs += 100;
          if (_silentMs >= 500 && _recording) {
            _silentMs = 0;
            _stopRecording();
          }
        }
      });
      await _rec.start(const RecordConfig(), path: '');
    } catch (_) {
      if (mounted) setState(() => _recording = false);
    }
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();
    await _ampSub?.cancel();
    String? path;
    try {
      path = await _rec.stop();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _recording = false;
      _state = BrainState.thinking;
    });
    if (path == null || path.isEmpty) return;
    try {
      final b64 = await readAudioAsBase64(path);
      final text = await _service.sttTranscribe(b64, format: 'webm');
      if (!mounted) return;
      if (text.trim().isNotEmpty) {
        _input.text = text;
        await _send(text);
      } else {
        setState(() => _state = BrainState.idle);
      }
    } catch (_) {
      if (mounted) setState(() => _state = BrainState.idle);
    }
  }

  @override
  void dispose() {
    _memoryCycle?.cancel();
    _recordingTimer?.cancel();
    _ampSub?.cancel();
    _interruptAmpSub?.cancel();
    _connSub?.cancel();
    _breathe.dispose();
    _pulse.dispose();
    _input.dispose();
    // 全局单例：页面销毁不关闭连接/会话，供下次进入热复用
    super.dispose();
  }

  Color _accent() => const Color(0xFF00D4FF);
  Color _accentSoft() => const Color(0xFF7FE7FF);

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 6) return '夜深了';
    if (h < 11) return '早上好';
    if (h < 14) return '中午好';
    if (h < 18) return '下午好';
    return '晚上好';
  }

  String _stateLabel() => switch (_state) {
        BrainState.idle => '● 待机',
        BrainState.listening => '● 聆听中',
        BrainState.thinking => '○ 思考中',
        BrainState.speaking => '▮ 说话中',
      };

  double _glowBlur() => switch (_state) {
        BrainState.speaking => 120,
        BrainState.listening => 100,
        _ => 90,
      };

  @override
  Widget build(BuildContext context) {
    final hasMessages = _messages.isNotEmpty || _inChat;
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          colors: [Color(0xFF0E1B3D), Color(0xFF060A18)],
          radius: 1.2,
          center: Alignment(0, -0.6),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _topBar(),
            const SizedBox(height: 12),
            // 问候语
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${_greeting()}，',
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFEAF0FF)),
                      ),
                      TextSpan(
                        text: '曲炳阳',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: _accentSoft()),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 视图切换：我的对话 / 互联对话
            _viewSwitcher(),
            const SizedBox(height: 14),
            if (_viewMode == 0) ...[
              // 正在交互的外脑（区别于顶栏「当前外脑」= 登录档案）
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 26),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('正在交互',
                      style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6B7794),
                          letterSpacing: 1.5)),
                ),
              ),
              const SizedBox(height: 8),
              _matrixBar(),
              const SizedBox(height: 10),
              // 主体：无对话时显示光球，有对话时显示消息列表
              Expanded(
                child: hasMessages ? _messageList() : _orbCenter(),
              ),
              // 录音回显：音量条 + 计时
              if (_recording) _recordingBar(),
              // 底部输入框
              _inputBar(),
            ] else ...[
              // 互联对话：别人和我的外脑的交互记录
              Expanded(child: _interlinkView()),
            ],
          ],
        ),
      ),
    );
  }

  /// 顶部视图切换：我的对话 / 互联对话
  Widget _viewSwitcher() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26),
      child: Row(
        children: [
          _viewTab('我的对话', 0),
          const SizedBox(width: 10),
          _viewTab('互联对话', 1),
        ],
      ),
    );
  }

  Widget _viewTab(String label, int mode) {
    final on = _viewMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() => _viewMode = mode);
        if (mode == 1) _loadInterlink();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: on
              ? const Color(0xFF00D4FF).withValues(alpha: 0.18)
              : const Color(0x0DFFFFFF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: on
                ? const Color(0xFF00D4FF).withValues(alpha: 0.7)
                : const Color(0x17FFFFFF),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: on ? FontWeight.w700 : FontWeight.w500,
            color: on ? const Color(0xFF00D4FF) : const Color(0xFF9AA7C7),
          ),
        ),
      ),
    );
  }

  /// 互联对话视图：别人和我的外脑的交互记录
  Widget _interlinkView() {
    if (_interlinkCards.isEmpty) {
      return const Center(
        child: Text(
          '还没有互联对话记录\n当别人通过授权和你的外脑对话时，这里会留下存档',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF6B7794), fontSize: 13, height: 1.6),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: _interlinkCards.length,
      itemBuilder: (context, i) => _interlinkCard(_interlinkCards[i]),
    );
  }

  Widget _interlinkCard(MemoryCard c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x0DFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x17FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.hub_outlined, size: 16, color: Color(colorOf(c.category))),
              const SizedBox(width: 6),
              Expanded(
                child: Text(c.title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFEAF0FF))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(c.content,
              style: const TextStyle(
                  fontSize: 12.5, color: Color(0xFFB9C4DD), height: 1.5)),
          const SizedBox(height: 6),
          Text(c.happenedAt,
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B7794))),
        ],
      ),
    );
  }

  /// 外脑矩阵板块：横向卡片，点选切换对话对象
  Widget _matrixBar() {
    return SizedBox(
      height: 76,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _peers.length,
        itemBuilder: (context, i) => _peerCard(i),
      ),
    );
  }

  Widget _peerCard(int i) {
    final p = _peers[i];
    final active = i == _activePeer;
    return GestureDetector(
      onTap: () => _onPeerTap(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? p.color.withValues(alpha: 0.18) : const Color(0x0DFFFFFF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? p.color.withValues(alpha: 0.7) : const Color(0x17FFFFFF),
            width: active ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    p.color.withValues(alpha: 0.95),
                    p.color.withValues(alpha: 0.4),
                  ],
                ),
                boxShadow: active
                    ? [
                        BoxShadow(
                            color: p.color.withValues(alpha: 0.5),
                            blurRadius: 14),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  p.name.substring(0, 1),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name,
                    style: TextStyle(
                        color: active ? Colors.white : const Color(0xFF9AA7C7),
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                Text(p.isSelf ? '我的外脑' : p.owner,
                    style: TextStyle(
                        color: active
                            ? p.color.withValues(alpha: 0.9)
                            : const Color(0xFF6B7794),
                        fontSize: 10.5)),
              ],
            ),
            if (active) ...[
              const SizedBox(width: 8),
              Icon(Icons.check_circle, size: 14, color: p.color),
            ],
          ],
        ),
      ),
    );
  }

  /// 切换对话对象：清空当前消息，提示已切换
  void _onPeerTap(int i) {
    if (i == _activePeer) return;
    setState(() {
      _activePeer = i;
      _messages.clear();
    });
  }

  /// 匹配语音/文字触发路由：返回 (外脑下标, 剩余消息)
  (int, String)? _matchPeerRoute(String text) {
    for (int i = 0; i < _peers.length; i++) {
      final p = _peers[i];
      final patterns = [
        '找${p.name}',
        '跟${p.name}说',
        '和${p.name}说',
        '问${p.name}',
      ];
      for (final pat in patterns) {
        final idx = text.indexOf(pat);
        if (idx >= 0) {
          final rest = text.substring(idx + pat.length).trim();
          return (i, rest);
        }
      }
    }
    return null;
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 当前登录外脑：点击切换档案
          Flexible(
            child: GestureDetector(
              onTap: _showProfileSwitcher,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _profiles[_activeProfile].color),
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      _profiles[_activeProfile].name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFEAF0FF)),
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(Icons.expand_more,
                      size: 18, color: Color(0xFF7E8BB0)),
                ],
              ),
            ),
          ),
          Row(
            children: [
              // 连接状态指示
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _connected
                      ? const Color(0xFF00E5A0)
                      : (_connecting ? const Color(0xFFFFB020) : const Color(0xFF6B7794)),
                ),
              ),
              const SizedBox(width: 8),
              _modelTag(),
              const SizedBox(width: 8),
              const _SignalBars(),
            ],
          ),
        ],
      ),
    );
  }

  /// 当前模型标识（顶部，简写 deepseek-v4-pro）
  Widget _modelTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: _accent().withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: _accent().withValues(alpha: 0.3)),
      ),
      child: Text(
        'v4-pro',
        style:
            TextStyle(fontSize: 9.5, color: _accentSoft(), letterSpacing: 0.3),
      ),
    );
  }

  Widget _orbCenter() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final orbSize = (constraints.maxHeight * 0.5).clamp(90.0, 260.0);
        // 窄屏（手机框/小窗）下光球+文字堆叠会溢出，包一层滚动兜底
        return SingleChildScrollView(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _orbZone(size: orbSize),
                const SizedBox(height: 16),
                Text(_stateLabel(),
                    style: const TextStyle(
                        color: Color(0xFF7E8BB0),
                        fontSize: 13,
                        letterSpacing: 2)),
                const SizedBox(height: 8),
                Text(
                  _connected ? '轻触光球，跟外脑说句话' : '正在连接外脑…',
                  style: TextStyle(
                      color: _accentSoft().withValues(alpha: 0.6), fontSize: 12),
                ),
                const SizedBox(height: 16),
                // 上下文记忆轮播
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: Text(
                    _memories[_memoryIndex],
                    key: ValueKey(_memoryIndex),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: _accentSoft().withValues(alpha: 0.5),
                        fontSize: 11,
                        height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _messageList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (context, i) {
        final m = _messages[i];
        return _bubble(m);
      },
    );
  }

  Widget _bubble(ChatMessage m) {
    final isUser = m.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          color: isUser
              ? _accent().withValues(alpha: 0.18)
              : const Color(0x12FFFFFF),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isUser ? 14 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 14),
          ),
          border: Border.all(
              color: isUser ? _accent().withValues(alpha: 0.4) : const Color(0x17FFFFFF)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              m.text + (m.streaming ? '▍' : ''),
              style: TextStyle(
                  fontSize: 13.5,
                  color: isUser ? const Color(0xFFEAF0FF) : const Color(0xFFD6E2FF),
                  height: 1.6),
            ),
            if (!isUser && m.audioBase64 != null) ...[
              const SizedBox(height: 8),
              _voiceBubble(m.audioBase64!),
            ],
          ],
        ),
      ),
    );
  }

  /// 语音消息气泡：点击播放/重播，播放中点击停止
  Widget _voiceBubble(String audioBase64) {
    return GestureDetector(
      onTap: () {
        if (_recording) return; // 录音中不能播放
        if (_playing) {
          // 播放中：点一下停止（微信标准）
          _play.stop();
          if (mounted) setState(() => _playing = false);
          return;
        }
        _playAudio(audioBase64);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _accent().withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _accent().withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_arrow, size: 16, color: _accentSoft()),
            const SizedBox(width: 4),
            Icon(Icons.graphic_eq, size: 14, color: _accentSoft()),
            const SizedBox(width: 6),
            Text('语音',
                style: TextStyle(fontSize: 12, color: _accentSoft())),
          ],
        ),
      ),
    );
  }

  /// 录音回显条：音量 + 计时
  Widget _recordingBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x22FF5C7A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x88FF5C7A)),
      ),
      child: Row(
        children: [
          Icon(Icons.mic, size: 16, color: const Color(0xFFFF5C7A)),
          const SizedBox(width: 8),
          Text('录音中 ${_fmtDuration(_recordingSeconds)}',
              style: const TextStyle(fontSize: 12.5, color: Color(0xFFFFB0C0))),
          const SizedBox(width: 12),
          Expanded(child: _volumeBar()),
          const SizedBox(width: 8),
          Text('点击停止',
              style: TextStyle(
                  fontSize: 11, color: Colors.white.withValues(alpha: 0.6))),
        ],
      ),
    );
  }

  /// 音量条：按 _amplitude（0..1）点亮格子
  Widget _volumeBar() {
    const bars = 20;
    final lit = (_amplitude * bars).round();
    return Row(
      children: List.generate(bars, (i) {
        final on = i < lit;
        return Container(
          width: 3,
          height: 6 + (i % 3) * 2.0,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: on ? const Color(0xFF00E5A0) : const Color(0x22FFFFFF),
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }

  String _fmtDuration(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  Widget _inputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF080E1E).withValues(alpha: 0.9),
        border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.07))),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _connected && !_sending ? _toggleRecording : null,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _recording
                    ? const Color(0x33FF5C7A)
                    : const Color(0x0DFFFFFF),
                border: Border.all(
                  color: _recording
                      ? const Color(0xFFFF5C7A)
                      : const Color(0x17FFFFFF),
                ),
              ),
              child: Icon(
                _recording ? Icons.stop : Icons.mic,
                color: _recording
                    ? const Color(0xFFFF5C7A)
                    : _accentSoft(),
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _connected && !_sending ? _toggleCallMode : null,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _callMode ? const Color(0x33FF5C7A) : const Color(0x0DFFFFFF),
                border: Border.all(
                  color: _callMode ? const Color(0xFFFF5C7A) : const Color(0x17FFFFFF),
                ),
              ),
              child: Icon(
                _callMode ? Icons.call_end : Icons.call,
                color: _callMode ? const Color(0xFFFF5C7A) : _accentSoft(),
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _input,
              enabled: _connected,
              style: const TextStyle(fontSize: 14, color: Color(0xFFE8EEFF)),
              decoration: InputDecoration(
                hintText: _connected ? '跟外脑说点什么…' : '连接中…',
                hintStyle: const TextStyle(color: Color(0xFF6B7794)),
                filled: true,
                fillColor: const Color(0x0DFFFFFF),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _send(_input.text),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _connected && !_sending ? () => _send(_input.text) : null,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    _accent(),
                    _accent().withValues(alpha: 0.7),
                  ],
                ),
              ),
              child: Icon(
                Icons.arrow_upward,
                color: _connected ? Colors.white : const Color(0xFF6B7794),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _orbZone({double size = 280}) {
    final orb = size * 0.607;
    final ring1 = size * 0.95;
    final ring2 = size * 0.78;
    return GestureDetector(
      onTap: _onOrbTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            _ring(size: ring1, color: _accent(), opacityFactor: 0.15, delayMs: 0),
            _ring(size: ring2, color: _accent(), opacityFactor: 0.35, delayMs: 600),
            _orb(diameter: orb),
          ],
        ),
      ),
    );
  }

  Widget _orb({double diameter = 170}) {
    return AnimatedBuilder(
      animation: _breathe,
      builder: (context, child) {
        final scale = 1.0 + 0.07 * Curves.easeInOut.transform(_breathe.value);
        return Transform.scale(
          scale: scale,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            width: diameter,
            height: diameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [Color(0xFF9EF0FF), Color(0xFF00D4FF), Color(0xFF0650C8)],
                stops: [0.0, 0.45, 0.8],
                center: Alignment(-0.3, -0.4),
              ),
              boxShadow: [
                BoxShadow(
                  color: _accent().withValues(alpha: 0.55),
                  blurRadius: _glowBlur(),
                  spreadRadius: 6,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _ring({
    required double size,
    required Color color,
    required double opacityFactor,
    required int delayMs,
  }) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final v = (_pulse.value + delayMs / 2400.0) % 1.0;
        final s = 1.0 + 0.3 * v;
        final o = opacityFactor * (1 - v);
        return Transform.scale(
          scale: s,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: o), width: 1.5),
            ),
          ),
        );
      },
    );
  }
}

class _SignalBars extends StatelessWidget {
  const _SignalBars();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: const [
        _Bar(h: 4),
        _Bar(h: 6),
        _Bar(h: 9),
        _Bar(h: 12),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  final double h;
  const _Bar({required this.h});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: h,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF0FF),
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}
