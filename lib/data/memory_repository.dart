/// 数据仓库抽象。
///
/// 现在是 `StaticRepository`（读 seed_data.dart，随 App 打包）。
/// 未来接 `hermes serve` 时新增 `ServerRepository`（WebSocket/HTTP），
/// 页面层零改动 —— 只需替换注入的仓库实现。
library;

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
