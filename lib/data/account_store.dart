import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 账号登录态存储：一个账号对应一个外脑（profile）。
///
/// 键 `account_session_v1` 存 `{username, profile}`（JSON）。
/// 登录/注册成功后 `login` 写入；启动时 `current` 判断是否已登录。
class AccountStore {
  static const _key = 'account_session_v1';
  static Map<String, String>? _cache;

  static Future<bool> get isLoggedIn async => (await current) != null;

  static Future<Map<String, String>?> get current async {
    if (_cache != null) return _cache;
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null) return null;
    _cache = Map<String, String>.from(jsonDecode(raw) as Map);
    return _cache;
  }

  /// 登录态内当前绑定的外脑 profile（如 animatrix / matrix-wang）。
  static String? get profile => _cache?['profile'];

  static Future<void> login(String username, String profile) async {
    _cache = {'username': username, 'profile': profile};
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(_cache));
  }

  static Future<void> logout() async {
    _cache = null;
    final p = await SharedPreferences.getInstance();
    await p.remove(_key);
  }

  /// 清除内存缓存（测试用，模拟重启后重新读本地）。
  static void reset() => _cache = null;
}
