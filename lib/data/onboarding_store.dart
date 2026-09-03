import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 首次引导结果存储（内存缓存 + 本地持久化）。
///
/// 键为 `onboarding_profile_v1`，存一个 `Map<String,String>`：
/// {name, gender, birthYear, role, city, height, sport, diet, hobbies, expectations}
/// 完成引导后 `save` 写入；启动时 `isCompleted` 判断是否已引导过。
class OnboardingStore {
  static const _key = 'onboarding_profile_v1';
  static Map<String, String>? _cache;

  static Future<bool> get isCompleted async => (await _load()) != null;

  static Future<Map<String, String>?> _load() async {
    if (_cache != null) return _cache;
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null) return null;
    _cache = Map<String, String>.from(jsonDecode(raw) as Map);
    return _cache;
  }

  /// 当前会话内的引导结果（供看板页读名字，无持久化时返回 null）。
  static Map<String, String>? get cached => _cache;

  static Future<void> save(Map<String, String> data) async {
    _cache = Map.of(data);
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(data));
  }

  /// 清除内存缓存（测试用，模拟 App 重启后重新从本地读）。
  static void reset() => _cache = null;
}
