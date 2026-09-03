/// 数据仓库抽象。
///
/// 现在是 `StaticRepository`（读 seed_data.dart，随 App 打包）。
/// 未来接 `hermes serve` 时新增 `ServerRepository`（WebSocket/HTTP），
/// 页面层零改动 —— 只需替换注入的仓库实现。
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/seed_data.dart';
import '../models/memory_card.dart';

abstract class MemoryRepository {
  Future<List<MemoryCard>> fetchCards();
  Future<List<Exobrain>> fetchExobrains();
  Future<List<Authorization>> fetchAuthorization();
}

/// 静态实现：数据随 App 打包（seed_data.dart 由 export_seed.mjs 生成）。
class StaticRepository implements MemoryRepository {
  const StaticRepository();

  @override
  Future<List<MemoryCard>> fetchCards() async =>
      SeedData.memoryCards.map(MemoryCard.fromMap).toList();

  @override
  Future<List<Exobrain>> fetchExobrains() async =>
      SeedData.exobrains.map(Exobrain.fromMap).toList();

  @override
  Future<List<Authorization>> fetchAuthorization() async =>
      SeedData.authorization.map(Authorization.fromMap).toList();
}

/// 服务端实现：从 memory_server（http://127.0.0.1:9118）实时读 data.js。
/// 每次 fetch 都重新拉取，data.js 一更新 App 即反映最新记忆，根治 seed 快照滞后。
class ServerRepository implements MemoryRepository {
  const ServerRepository({this.baseUrl = 'https://28e65b06.r20.vip.cpolar.cn'});

  final String baseUrl;

  @override
  Future<List<MemoryCard>> fetchCards() async {
    final json = await _get('/api/memory');
    final skills = (json['skills'] ?? const []) as List;
    return skills
        .map((s) => MemoryCard.fromMap(s as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<Exobrain>> fetchExobrains() async {
    final json = await _get('/api/exobrains');
    final list = (json['exobrains'] ?? const []) as List;
    return list
        .map((e) => Exobrain.fromMap((e as Map).cast<String, String>()))
        .toList();
  }

  @override
  Future<List<Authorization>> fetchAuthorization() async {
    final json = await _get('/api/exobrains');
    final list = (json['authorization'] ?? const []) as List;
    return list
        .map((a) => Authorization.fromMap((a as Map).cast<String, String>()))
        .toList();
  }

  Future<Map<String, dynamic>> _get(String path) async {
    final resp = await http.get(Uri.parse('$baseUrl$path'));
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}: $path');
    }
    return jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
  }
}
