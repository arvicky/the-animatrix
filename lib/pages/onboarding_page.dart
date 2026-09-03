import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../data/onboarding_store.dart';
import '../services/audio_utils.dart';
import '../services/conversation_service.dart';
import '../widgets/glow_background.dart';

/// 首次登录引导 —— 像认识新朋友，快速建立基础画像。
///
/// 双通道：① 可视化点选/输入（主）② 语音输入（每步右下角麦克风，按住说）
/// 只覆盖低敏感维度（身份/身体/偏好/价值观期望），性格/认知/关系/经历
/// 留到常驻引导慢慢补（见 E:\animatrix\外脑引导机制完整设计.md）。
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  static const _total = 7; // 步 0..6
  int _step = 0;

  // 各步答案
  final TextEditingController _name = TextEditingController();
  final TextEditingController _year = TextEditingController();
  final TextEditingController _height = TextEditingController();
  final TextEditingController _extra = TextEditingController(); // 偏好补充
  String? _gender;
  String? _role;
  String? _sport;
  final Set<String> _hobbies = {};
  final Set<String> _expects = {};

  static const _genders = ['男', '女', '其他'];
  static const _roles = ['学生', '上班族', '创业者', '自由职业', '其他'];
  static const _sports = ['爱运动', '偶尔', '基本不动'];
  static const _hobbyOptions = [
    '韩料', '烧鸟', '咖啡', '火锅', '甜品', '羽毛球', '健身', '游戏', '逛展',
    '露营', '动漫', '电影', '音乐', '读书', '古着', '穿搭', '数码', '车',
  ];
  static const _expectOptions = [
    ('🧠', '记住我的想法和灵感'),
    ('📚', '帮我整理知识、总结经验'),
    ('⏰', '提醒我、跟进我的计划'),
    ('💬', '陪我聊天、理解我'),
  ];

  bool get _isLast => _step == _total - 1;
  bool get _canSkip => _step != 1; // 只有「称呼」不可跳过

  void _next() {
    if (_step < _total - 1) setState(() => _step++);
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  Future<void> _finish() async {
    await OnboardingStore.save({
      'name': _name.text.trim(),
      'gender': _gender ?? '',
      'birthYear': _year.text.trim(),
      'role': _role ?? '',
      'height': _height.text.trim(),
      'sport': _sport ?? '',
      'hobbies': _hobbies.join('、'),
      'hobbiesExtra': _extra.text.trim(),
      'expectations': _expects.join('、'),
    });
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return GlowBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              _progressBar(),
              Expanded(child: _stepBody()),
              _bottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _progressBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (_step + 1) / _total,
                minHeight: 6,
                backgroundColor: const Color(0x22FFFFFF),
                color: const Color(0xFF00D4FF),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text('${_step + 1}/$_total',
              style: const TextStyle(
                  fontSize: 12.5, color: Color(0xFF9AA7C7))),
        ],
      ),
    );
  }

  Widget _stepBody() {
    switch (_step) {
      case 0:
        return _welcome();
      case 1:
        return _nameStep();
      case 2:
        return _identityStep();
      case 3:
        return _bodyStep();
      case 4:
        return _hobbyStep();
      case 5:
        return _expectStep();
      default:
        return _doneStep();
    }
  }

  // 通用外脑提问头 + 内容
  Widget _ask(String question, String hint, Widget child) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Orb(radius: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0x0DFFFFFF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0x17FFFFFF)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(question,
                        style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFE8EEFF),
                            height: 1.4)),
                    if (hint.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(hint,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF9AA7C7))),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        child,
      ],
    );
  }

  Widget _welcome() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _Orb(radius: 56),
            const SizedBox(height: 28),
            const Text('你好，我是你的外脑',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFE8EEFF))),
            const SizedBox(height: 12),
            const Text(
              '一个替你记住一切、越来越懂你的第二大脑。\n开始前，我想先认识你一下，几分钟就好。',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, color: Color(0xFF9AA7C7), height: 1.6),
            ),
            const SizedBox(height: 12),
            const Text('你说，我记；你问，我答；我还记得你的一切。',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, color: Color(0xFF00D4FF), height: 1.5)),
          ],
        ),
      ),
    );
  }

  Widget _nameStep() {
    return _ask('先告诉我，该怎么称呼你？', '这是唯一必填的一项，外脑得先有个称呼。',
        Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _name,
          autofocus: true,
          style: const TextStyle(color: Color(0xFFE8EEFF), fontSize: 16),
          decoration: _inputDec('你的名字 / 昵称'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),
        _VoiceField(onTranscript: (t) {
          _name.text = t;
          setState(() {});
        }),
      ],
    ));
  }

  Widget _identityStep() {
    return _ask('简单说说你，让我对你有第一印象。', '都可跳过，我以后慢慢了解。',
        Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('性别'),
        Wrap(spacing: 8, children: [
          for (final g in _genders)
            _chip(g, _gender == g, () => setState(() => _gender = g)),
        ]),
        const SizedBox(height: 16),
        _label('出生年份'),
        TextField(
          controller: _year,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Color(0xFFE8EEFF), fontSize: 16),
          decoration: _inputDec('如 1997'),
        ),
        const SizedBox(height: 16),
        _label('你的身份'),
        Wrap(spacing: 8, children: [
          for (final r in _roles)
            _chip(r, _role == r, () => setState(() => _role = r)),
        ]),
      ],
    ));
  }

  Widget _bodyStep() {
    return _ask('了解下你的身体和习惯。', '可跳过。',
        Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('身高（cm）'),
        TextField(
          controller: _height,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Color(0xFFE8EEFF), fontSize: 16),
          decoration: _inputDec('如 175'),
        ),
        const SizedBox(height: 16),
        _label('平时爱运动吗'),
        Wrap(spacing: 8, children: [
          for (final s in _sports)
            _chip(s, _sport == s, () => setState(() => _sport = s)),
        ]),
      ],
    ));
  }

  Widget _hobbyStep() {
    return _ask('你平时喜欢点什么？这样我以后能主动跟你聊。', '多选，也可以按住麦克风补充。',
        Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final h in _hobbyOptions)
            _chip(h, _hobbies.contains(h), () {
              setState(() => _hobbies.contains(h)
                  ? _hobbies.remove(h)
                  : _hobbies.add(h));
            }),
        ]),
        const SizedBox(height: 16),
        TextField(
          controller: _extra,
          style: const TextStyle(color: Color(0xFFE8EEFF), fontSize: 15),
          decoration: _inputDec('还有什么想补充的'),
        ),
        const SizedBox(height: 14),
        _VoiceField(onTranscript: (t) {
          _extra.text = t;
          setState(() {});
        }),
      ],
    ));
  }

  Widget _expectStep() {
    return _ask('你最想让我帮你做哪件事？', '多选。',
        Column(
      children: [
        for (final (e, label) in _expectOptions)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            child: _expectTile(e, label),
          ),
      ],
    ));
  }

  Widget _expectTile(String emoji, String label) {
    final on = _expects.contains(label);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => setState(
          () => on ? _expects.remove(label) : _expects.add(label)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: on ? const Color(0x2200D4FF) : const Color(0x0BFFFFFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: on ? const Color(0x8800D4FF) : const Color(0x17FFFFFF)),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 14.5, color: Color(0xFFE8EEFF))),
            ),
            Icon(on ? Icons.check_circle : Icons.circle_outlined,
                size: 20,
                color: on ? const Color(0xFF00D4FF) : const Color(0xFF4A5570)),
          ],
        ),
      ),
    );
  }

  Widget _doneStep() {
    final name = _name.text.trim().isEmpty ? '朋友' : _name.text.trim();
    final parts = <String>[];
    if (_year.text.trim().isNotEmpty) parts.add('${_year.text.trim()} 年出生');
    if (_gender != null) parts.add(_gender!);
    if (_role != null) parts.add(_role!);
    final tagline = parts.isEmpty ? '从今天起，我认识你了。' : parts.join(' · ');
    final bodyParts = <String>[
      if (_height.text.trim().isNotEmpty) '身高 ${_height.text.trim()}cm',
      ?_sport,
    ];
    final hobbyLine = _hobbies.isEmpty
        ? '以后我会慢慢了解你的喜好。'
        : '你喜欢 ${_hobbies.join('、')}，我记下了。';
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      children: [
        const Center(
          child: _Orb(radius: 46),
        ),
        const SizedBox(height: 24),
        Center(
          child: Text('你好，$name',
              style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFE8EEFF))),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(tagline,
              style: const TextStyle(fontSize: 14, color: Color(0xFF9AA7C7))),
        ),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0x1400D4FF), Color(0x127B61FF)]),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x4000D4FF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('这是你的初始画像',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF00D4FF))),
              const SizedBox(height: 10),
              _profileLine(Icons.badge_outlined, '身份', parts.isEmpty ? '待补充' : parts.join('、')),
              _profileLine(Icons.accessibility_new, '身体',
                  bodyParts.isEmpty ? '待补充' : bodyParts.join('、')),
              _profileLine(Icons.favorite_outline, '偏好',
                  _hobbies.isEmpty ? '待补充' : _hobbies.join('、')),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          '$hobbyLine\n以后你的想法、经历、灵感，我帮你慢慢攒成一个越来越懂你的自己。现在，你想跟我聊点什么？',
          style: const TextStyle(
              fontSize: 13.5, color: Color(0xFFC9D4EE), height: 1.6),
        ),
      ],
    );
  }

  Widget _profileLine(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF00D4FF)),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12.5, color: Color(0xFF9AA7C7))),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFFE8EEFF), height: 1.4)),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        children: [
          if (_step > 0)
            TextButton(
              onPressed: _back,
              child: const Text('上一步',
                  style: TextStyle(color: Color(0xFF9AA7C7))),
            )
          else
            const SizedBox(width: 64),
          const Spacer(),
          if (_isLast)
            _primaryBtn('进入外脑', _finish)
          else ...[
            if (_canSkip)
              TextButton(
                onPressed: _next,
                child: const Text('跳过',
                    style: TextStyle(color: Color(0xFF9AA7C7))),
              ),
            const SizedBox(width: 8),
            _primaryBtn(
              _step == 0 ? '开始认识我' : '下一步',
              _step == 1 && _name.text.trim().isEmpty ? null : _next,
            ),
          ],
        ],
      ),
    );
  }

  Widget _primaryBtn(String label, VoidCallback? onTap) {
    final disabled = onTap == null;
    return Container(
      decoration: BoxDecoration(
        gradient: disabled
            ? null
            : const LinearGradient(
                colors: [Color(0xFF00D4FF), Color(0xFF0650C8)]),
        color: disabled ? const Color(0x22FFFFFF) : null,
        borderRadius: BorderRadius.circular(24),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
          child: Text(label,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: disabled
                      ? const Color(0xFF6B7794)
                      : const Color(0xFF061428))),
        ),
      ),
    );
  }

  Widget _label(String t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(t,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF9AA7C7))),
    );
  }

  Widget _chip(String label, bool on, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: on ? const Color(0x2200D4FF) : const Color(0x0BFFFFFF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: on ? const Color(0x8800D4FF) : const Color(0x17FFFFFF)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13.5,
                fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                color: on ? const Color(0xFF00D4FF) : const Color(0xFFC9D4EE))),
      ),
    );
  }

  InputDecoration _inputDec(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF4A5570), fontSize: 15),
      filled: true,
      fillColor: const Color(0x0BFFFFFF),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0x17FFFFFF)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0x17FFFFFF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0x8800D4FF)),
      ),
    );
  }
}

/// 光球（外脑形象）—— 静态版，引导页够用。
class _Orb extends StatelessWidget {
  const _Orb({required this.radius});
  final double radius;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF7FE7FF), Color(0xFF00D4FF), Color(0xFF0650C8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF00D4FF).withValues(alpha: 0.35),
              blurRadius: radius,
              spreadRadius: 2),
        ],
      ),
    );
  }
}

/// 语音输入按钮 —— 按住说，松手自动转文字填回。
class _VoiceField extends StatefulWidget {
  const _VoiceField({required this.onTranscript});
  final void Function(String text) onTranscript;
  @override
  State<_VoiceField> createState() => _VoiceFieldState();
}

class _VoiceFieldState extends State<_VoiceField> {
  final _recorder = AudioRecorder();
  bool _recording = false;
  bool _busy = false;
  String? _error;

  Future<void> _start() async {
    if (_recording || _busy) return;
    try {
      if (!await _recorder.hasPermission()) return;
      setState(() {
        _recording = true;
        _error = null;
      });
      await _recorder.start(const RecordConfig(), path: '');
    } catch (_) {
      if (mounted) setState(() => _recording = false);
    }
  }

  Future<void> _stop() async {
    if (!_recording) return;
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _recording = false;
      _busy = true;
    });
    if (path == null || path.isEmpty) {
      setState(() => _busy = false);
      return;
    }
    try {
      await ConversationService.instance.connect();
      final b64 = await readAudioAsBase64(path);
      final text = await ConversationService.instance.sttTranscribe(b64);
      if (!mounted) return;
      if (text.trim().isNotEmpty) {
        widget.onTranscript(text.trim());
      } else {
        setState(() => _error = '没听清，再说一次或直接输入');
      }
    } catch (_) {
      if (mounted) setState(() => _error = '语音转写不可用，请手动输入');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTapDown: (_) => _start(),
          onTapUp: (_) => _stop(),
          onTapCancel: _stop,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _recording
                  ? const Color(0x22FF5C7A)
                  : const Color(0x2200D4FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: _recording
                      ? const Color(0x88FF5C7A)
                      : const Color(0x4400D4FF)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                    _recording ? Icons.mic : Icons.mic_none,
                    size: 18,
                    color: _recording
                        ? const Color(0xFFFF8FA0)
                        : const Color(0xFF00D4FF)),
                const SizedBox(width: 8),
                Text(
                  _recording ? '松手结束' : (_busy ? '识别中…' : '按住说'),
                  style: TextStyle(
                      fontSize: 13.5,
                      color: _recording
                          ? const Color(0xFFFF8FA0)
                          : const Color(0xFF00D4FF),
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF9AA7C7))),
          ),
      ],
    );
  }
}
