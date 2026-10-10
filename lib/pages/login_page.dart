import 'package:flutter/material.dart';

import '../data/account_store.dart';
import '../data/memory_repository.dart';
import '../models/memory_card.dart';

/// 登录 / 注册页。
///
/// 登录成功 → onLogin（直接进主界面，跳过引导）；
/// 注册成功（新外脑绑定账号）→ onRegistered（进首次引导）。
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.onLogin, required this.onRegistered});

  final VoidCallback onLogin;
  final VoidCallback onRegistered;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const _repo = ServerRepository();

  final _username = TextEditingController();
  final _password = TextEditingController();

  bool _register = false; // false=登录 true=注册
  bool _busy = false;
  String? _error;
  List<Exobrain> _exobrains = [];
  String? _profile; // 注册时选中的外脑

  @override
  void initState() {
    super.initState();
    _loadExobrains();
  }

  Future<void> _loadExobrains() async {
    try {
      final list = await _repo.fetchExobrains();
      if (mounted) setState(() => _exobrains = list);
    } catch (_) {}
  }

  Future<void> _submit() async {
    final u = _username.text.trim();
    final p = _password.text;
    if (u.isEmpty || p.isEmpty) {
      setState(() => _error = '账号和密码都不能为空');
      return;
    }
    if (_register && _profile == null) {
      setState(() => _error = '请选择要绑定的外脑');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final Map<String, String> r;
      if (_register) {
        r = await _repo.accountRegister(u, p, _profile!);
      } else {
        r = await _repo.accountLogin(u, p);
      }
      await AccountStore.login(r['username']!, r['profile']!);
      if (!mounted) return;
      if (_register) {
        widget.onRegistered();
      } else {
        widget.onLogin();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _friendly(e);
        _busy = false;
      });
    }
  }

  static String _friendly(Object e) {
    var s = e.toString();
    if (s.startsWith('Exception: ')) s = s.substring('Exception: '.length);
    return s.isEmpty ? '连接失败，请检查服务是否启动' : s;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060A18),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _logo(),
                  const SizedBox(height: 28),
                  _modeToggle(),
                  const SizedBox(height: 20),
                  if (_register) ..._registerFields(),
                  _field(_username, '账号', Icons.person_outline, obscure: false),
                  const SizedBox(height: 14),
                  _field(_password, '密码', Icons.lock_outline, obscure: true),
                  if (_error != null) ..._errorText(),
                  const SizedBox(height: 22),
                  _submitBtn(),
                  const SizedBox(height: 14),
                  const Text(
                    '一个账号对应一个外脑。注册后再次登录，直接进入你的外脑。',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7797)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _logo() {
    return Column(
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
                colors: [Color(0xFF00D4FF), Color(0xFF0650C8)]),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFF00D4FF).withValues(alpha: 0.35),
                  blurRadius: 24),
            ],
          ),
          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 32),
        ),
        const SizedBox(height: 18),
        const Text('外脑矩阵',
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Color(0xFFE8EEFF))),
        const SizedBox(height: 6),
        const Text('你的第二个大脑，替你记住一切',
            style: TextStyle(fontSize: 13, color: Color(0xFF9AA7C7))),
      ],
    );
  }

  Widget _modeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1226),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Row(
        children: [
          _modeBtn('登录', !_register),
          _modeBtn('注册新外脑', _register),
        ],
      ),
    );
  }

  Widget _modeBtn(String label, bool on) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() {
          _register = label == '注册新外脑';
          _error = null;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: on ? const Color(0xFF00D4FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: on ? const Color(0xFF060A18) : const Color(0xFF9AA7C7),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _registerFields() {
    return [
      _label('绑定到哪个外脑'),
      const SizedBox(height: 8),
      if (_exobrains.isEmpty)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: _boxDec(),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Color(0xFF9AA7C7)),
              SizedBox(width: 8),
              Expanded(
                child: Text('外脑清单加载中，或服务未连接…',
                    style: TextStyle(fontSize: 13, color: Color(0xFF9AA7C7))),
              ),
            ],
          ),
        )
      else
        DropdownButtonFormField<String>(
          initialValue: _profile,
          dropdownColor: const Color(0xFF0B1226),
          style: const TextStyle(color: Color(0xFFE8EEFF), fontSize: 15),
          decoration: _inputDec('选择外脑'),
          items: [
            for (final e in _exobrains)
              DropdownMenuItem(
                value: e.profile,
                child: Text('${e.owner}${e.nickname.isEmpty ? '' : '（${e.nickname}）'}'),
              ),
          ],
          onChanged: (v) => setState(() => _profile = v),
        ),
      const SizedBox(height: 16),
    ];
  }

  Widget _field(TextEditingController ctrl, String hint, IconData icon,
      {required bool obscure}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      style: const TextStyle(color: Color(0xFFE8EEFF), fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF6B7797)),
        prefixIcon: Icon(icon, size: 19, color: const Color(0xFF6B7797)),
        filled: true,
        fillColor: const Color(0xFF0B1226),
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0x1FFFFFFF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0x1FFFFFFF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF00D4FF)),
        ),
      ),
    );
  }

  List<Widget> _errorText() {
    return [
      const SizedBox(height: 12),
      Text(_error!,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: Color(0xFFFF5C7A))),
    ];
  }

  Widget _submitBtn() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF00D4FF), Color(0xFF0650C8)]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: _busy ? null : _submit,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(_register ? '注册并开始' : '登录',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(text,
        style: const TextStyle(
            fontSize: 12.5, color: Color(0xFF9AA7C7), fontWeight: FontWeight.w600));
  }

  BoxDecoration _boxDec() => BoxDecoration(
        color: const Color(0xFF0B1226),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      );

  InputDecoration _inputDec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF6B7797)),
        filled: true,
        fillColor: const Color(0xFF0B1226),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0x1FFFFFFF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0x1FFFFFFF)),
        ),
      );

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }
}
