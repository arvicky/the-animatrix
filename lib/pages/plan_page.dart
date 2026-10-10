import 'package:flutter/material.dart';

import '../data/memory_repository.dart';
import '../models/memory_card.dart';
import '../widgets/glow_background.dart';

/// 「规划」板块 —— 用户正在进行、未来计划、长期跟进的事务/项目/合作的全生命周期进度履历。
class PlanPage extends StatefulWidget {
  const PlanPage({super.key, required this.repository});

  final MemoryRepository repository;

  @override
  State<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends State<PlanPage> {
  late Future<List<MemoryCard>> _future;
  late DateTime _viewDate; // 当前查看的年月

  static const _statusColor = <String, Color>{
    '未完成': Color(0xFF9AA7C7),
    '进行中': Color(0xFF00D4FF),
    '已完成': Color(0xFF00E5A0),
  };

  @override
  void initState() {
    super.initState();
    _future = widget.repository.fetchCards();
    final now = DateTime.now();
    _viewDate = DateTime(now.year, now.month);
  }

  static bool _isPlan(MemoryCard c) {
    if (c.category == '规划' || c.category == '计划') return true;
    return c.tags.any((t) => t.contains('规划') || t.contains('计划'));
  }

  static String _ym(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return GlowBackground(
      child: FutureBuilder<List<MemoryCard>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final plans = snap.data!.where(_isPlan).toList();
          final viewYm = _ym(_viewDate);
          final visible = plans.where((p) {
            if (p.status == '已完成') {
              final doneYm = (p.updatedAt.length >= 7)
                  ? p.updatedAt.substring(0, 7)
                  : (p.day.length >= 7 ? p.day.substring(0, 7) : '');
              return doneYm == viewYm;
            }
            final createdYm =
                p.day.length >= 7 ? p.day.substring(0, 7) : '9999-99';
            return createdYm.compareTo(viewYm) <= 0;
          }).toList()
            ..sort((a, b) => b.happenedAt.compareTo(a.happenedAt));

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _monthHeader(),
              const SizedBox(height: 6),
              const Text(
                '未开始 / 进行中的事件持续展示；已完成的事件归档到完成当月。',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF9AA7C7)),
              ),
              const SizedBox(height: 14),
              if (visible.isEmpty)
                _empty()
              else
                ...visible.map((p) => _planCard(p, snap.data!)),
            ],
          );
        },
      ),
    );
  }

  Widget _monthHeader() {
    return Row(
      children: [
        _nav('‹', () => _changeMonth(-1)),
        Expanded(
          child: Center(
            child: Text(
              '${_viewDate.year}年${_viewDate.month}月',
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: Color(0xFFE8EEFF)),
            ),
          ),
        ),
        _nav('›', () => _changeMonth(1)),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => setState(() {
            final now = DateTime.now();
            _viewDate = DateTime(now.year, now.month);
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0x6600D4FF)),
            ),
            child: const Text('本月',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF00D4FF))),
          ),
        ),
      ],
    );
  }

  Widget _nav(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x5900D4FF)),
          color: const Color(0x1400D4FF),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: Color(0xFF00D4FF))),
      ),
    );
  }

  void _changeMonth(int delta) {
    setState(() {
      var y = _viewDate.year;
      var m = _viewDate.month + delta;
      if (m < 1) {
        m = 12;
        y--;
      } else if (m > 12) {
        m = 1;
        y++;
      }
      _viewDate = DateTime(y, m);
    });
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

  Widget _empty() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x5900D4FF)),
        color: const Color(0x0800D4FF),
      ),
      child: Column(
        children: const [
          Text('🗂️', style: TextStyle(fontSize: 36)),
          SizedBox(height: 8),
          Text('本月还没有规划事件',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF00D4FF))),
          SizedBox(height: 6),
          Text('说「帮我记录一条规划」，第一条事务就会出现在这里',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF9AA7C7))),
        ],
      ),
    );
  }

  Widget _planCard(MemoryCard p, List<MemoryCard> allCards) {
    final color = _statusColor[p.status] ?? const Color(0xFF00D4FF);
    // 关联记忆：tags 含「事件:标题」的卡（排除自己），自动并入进度时间线
    final related = allCards
        .where((c) => c.id != p.id && c.tags.contains('事件:${p.title}'))
        .toList()
      ..sort((a, b) => a.day.compareTo(b.day));
    final timeline = <String>[
      ...p.history,
      for (final r in related) '${r.day}：${r.title}',
    ]..sort();
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0x1400D4FF), Color(0x0F7B61FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(p.title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFE8EEFF))),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(p.status,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('生成 ${p.happenedAt}',
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF6B7794))),
              const SizedBox(width: 10),
              _accessTag(p.access),
            ],
          ),
          const SizedBox(height: 10),
          if (timeline.isNotEmpty) ...[
            const Text('进度时间线',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF00D4FF))),
            const SizedBox(height: 6),
            ...timeline.map((h) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(h.split('：').first + '：',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF6B7794))),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                            h.contains('：') ? h.substring(h.indexOf('：') + 1) : h,
                            style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFFC9D4EE),
                                height: 1.5)),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 4),
          ],
          if (p.content.isNotEmpty) ...[
            const Divider(height: 16, color: Color(0x17FFFFFF)),
            Text('下一步任务',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: color)),
            const SizedBox(height: 4),
            Text(p.content,
                style: const TextStyle(
                    fontSize: 12.5, color: Color(0xFFC9D4EE), height: 1.6)),
          ],
        ],
      ),
    );
  }
}
