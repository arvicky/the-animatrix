import 'package:flutter/material.dart';

import '../data/memory_repository.dart';
import '../models/memory_card.dart';
import '../widgets/glow_background.dart';

/// 「知识」tab —— 知识卡可视化（对应 dashboard/index.html）。
/// 统计卡 + 分类筛选 + 卡片网格，展示「知识资产在生长」。
class KnowledgePage extends StatefulWidget {
  const KnowledgePage({super.key, required this.repository});

  final MemoryRepository repository;

  @override
  State<KnowledgePage> createState() => _KnowledgePageState();
}

class _KnowledgePageState extends State<KnowledgePage> {
  late Future<List<MemoryCard>> _future;
  String _active = '全部';
  static const _cats = ['外脑设计', '工作经验', '踩坑复盘', '生活记忆', '灵光一闪'];

  @override
  void initState() {
    super.initState();
    _future = widget.repository.fetchCards();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MemoryCard>>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final cards = snap.data!;
        final list = _active == '全部'
            ? cards
            : cards.where((c) => c.category == _active).toList();
        return GlowBackground(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _stats(cards),
              const SizedBox(height: 16),
              _filters(),
              const SizedBox(height: 12),
              ...list.map(_card),
            ],
          ),
        );
      },
    );
  }

  Widget _stats(List<MemoryCard> cards) {
    final cats = cards.map((c) => c.category).toSet();
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    int week = 0;
    for (final c in cards) {
      final d = DateTime.tryParse(c.day);
      if (d != null && d.isAfter(weekAgo)) week++;
    }
    final tags = cards.expand((c) => c.tags).toSet();
    final items = [
      (cards.length, '知识卡'),
      (cats.length, '知识分类'),
      (week, '近 7 天沉淀'),
      (tags.length, '关键词标签'),
    ];
    return Row(
      children: [
        for (final (n, lab) in items) ...[
          Expanded(child: _statCell(n, lab)),
          if (lab != items.last.$2) const SizedBox(width: 10),
        ],
      ],
    );
  }

  Widget _statCell(int n, String lab) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0x1A00D4FF), Color(0x127B61FF)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x4700D4FF)),
      ),
      child: Column(
        children: [
          Text('$n',
              style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF00D4FF),
                  height: 1.1)),
          const SizedBox(height: 4),
          Text(lab,
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFFA9B6D8))),
        ],
      ),
    );
  }

  Widget _filters() {
    final names = ['全部', ..._cats];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final n in names)
          GestureDetector(
            onTap: () => setState(() => _active = n),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: n == _active
                      ? const Color(0xFF00D4FF)
                      : const Color(0x17FFFFFF),
                ),
                color: n == _active
                    ? const Color(0x3300D4FF)
                    : const Color(0x0BFFFFFF),
              ),
              child: Text(
                n,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: n == _active
                      ? const Color(0xFF00D4FF)
                      : const Color(0xFF9AA7C7),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _card(MemoryCard c) {
    final color = Color(colorOf(c.category));
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0x0E00D4FF), Color(0x05FFFFFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TopAccentLine(color: color),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: color),
                      ),
                      child: Text(c.category,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: color)),
                    ),
                    const SizedBox(width: 6),
                    _accessTag(c.access),
                    const Spacer(),
                    Text('v${c.version}',
                        style: const TextStyle(
                            fontSize: 10, color: Color(0xFF6B7794))),
                  ],
                ),
                const SizedBox(height: 10),
                Text(c.title,
                    style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFE8EEFF),
                        height: 1.4)),
                const SizedBox(height: 6),
                Text(c.content,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFFC9D4EE),
                        height: 1.6)),
                const SizedBox(height: 12),
                if (c.tags.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final t in c.tags)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0x0DFFFFFF),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0x17FFFFFF)),
                          ),
                          child: Text(t,
                              style: const TextStyle(
                                  fontSize: 10.5, color: Color(0xFF9AA7C7))),
                        ),
                    ],
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    _time('发生', c.happenedAt),
                    _time('更新', c.updatedAt),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _accessTag(String access) {
    final isAll = access == '所有人';
    final color = isAll ? const Color(0xFF00E5A0) : const Color(0xFFFFB020);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        isAll ? '🔓 所有人' : '🔒 仅个人',
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Widget _time(String label, String val) {
    return Row(
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF9AA7C7))),
        const SizedBox(width: 4),
        Text(val.isEmpty ? '—' : val,
            style: const TextStyle(fontSize: 10.5, color: Color(0xFFC9D4EE))),
      ],
    );
  }
}
