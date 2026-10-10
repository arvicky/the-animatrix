import 'package:flutter/material.dart';

import '../data/memory_repository.dart';
import '../models/memory_card.dart';
import '../widgets/glow_background.dart';

/// 「记忆」tab —— 每日记忆（对应 dashboard/daily.html）。
/// 核心 = 日历看板：年月可切换、整月铺开、有记忆的日期高亮显示条数、
/// 点某天切换到那天的记忆时间线。
class MemoryPage extends StatefulWidget {
  const MemoryPage({super.key, required this.repository});

  final MemoryRepository repository;

  @override
  State<MemoryPage> createState() => _MemoryPageState();
}

class _MemoryPageState extends State<MemoryPage> {
  late Future<List<MemoryCard>> _future;

  // 日历状态
  late DateTime _viewDate; // 当前查看的年月（取年月）
  String? _selectedDay; // 选中的日期 YYYY-MM-DD

  @override
  void initState() {
    super.initState();
    _future = widget.repository.fetchCards();
    final now = DateTime.now();
    _viewDate = DateTime(now.year, now.month);
    _selectedDay = _dayStr(now);
  }

  static String _dayStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _todayStr() => _dayStr(DateTime.now());

  @override
  Widget build(BuildContext context) {
    return GlowBackground(
      child: FutureBuilder<List<MemoryCard>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final cards = snap.data!;
          final byDay = <String, List<MemoryCard>>{};
          for (final c in cards) {
            byDay.putIfAbsent(c.day.isEmpty ? '未标注' : c.day, () => []).add(c);
          }
          // 当日所属事件：当天有进度记录的规划事件
          final today = _selectedDay ?? _todayStr();
          final dayPlans = cards.where((c) {
            final isPlan = c.category == '规划' ||
                c.category == '计划' ||
                c.tags.any((t) => t.contains('规划') || t.contains('计划'));
            return isPlan && c.history.any((h) => h.contains(today));
          }).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _calendar(byDay),
              if (dayPlans.isNotEmpty) ...[
                const SizedBox(height: 16),
                _dayPlans(dayPlans),
              ],
              const SizedBox(height: 16),
              _dayContent(byDay),
            ],
          );
        },
      ),
    );
  }

  // ===== 当日所属事件 =====

  Widget _dayPlans(List<MemoryCard> plans) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0x1400E5A0), Color(0x0F00D4FF)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x4000E5A0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('当日所属事件',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF00E5A0),
                  letterSpacing: 1)),
          const SizedBox(height: 8),
          ...plans.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Text('● ',
                        style:
                            TextStyle(fontSize: 10, color: Color(0xFF00E5A0))),
                    Expanded(
                      child: Text(p.title,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFE8EEFF))),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ===== 日历看板 =====

  Widget _calendar(Map<String, List<MemoryCard>> byDay) {
    final year = _viewDate.year;
    final month = _viewDate.month;
    final firstWeekday = DateTime(year, month, 1).weekday; // 1=周一 ... 7=周日
    final leading = firstWeekday % 7; // 周日开头：周日=0 周一=1 ... 周六=6
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final today = _todayStr();

    final cells = <Widget>[];
    for (var i = 0; i < leading; i++) {
      cells.add(const SizedBox());
    }
    for (var d = 1; d <= daysInMonth; d++) {
      final dayStr = _dayStr(DateTime(year, month, d));
      final has = byDay.containsKey(dayStr);
      final count = has ? byDay[dayStr]!.length : 0;
      cells.add(_dayCell(
        day: d,
        dayStr: dayStr,
        has: has,
        count: count,
        isToday: dayStr == today,
        isSelected: dayStr == _selectedDay,
      ));
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0x1400D4FF), Color(0x0F7B61FF)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x4000D4FF)),
      ),
      child: Column(
        children: [
          _calHeader(),
          const SizedBox(height: 10),
          _calWeekRow(),
          const SizedBox(height: 4),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            children: cells,
          ),
        ],
      ),
    );
  }

  Widget _calHeader() {
    return Row(
      children: [
        _calNav('‹', () => _changeMonth(-1)),
        Expanded(
          child: Center(
            child: Text('${_viewDate.year}年${_viewDate.month}月',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    color: Color(0xFFE8EEFF))),
          ),
        ),
        _calNav('›', () => _changeMonth(1)),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _backToToday,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0x6600D4FF)),
            ),
            child: const Text('今天',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF00D4FF))),
          ),
        ),
      ],
    );
  }

  Widget _calNav(String label, VoidCallback onTap) {
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

  Widget _calWeekRow() {
    const dow = ['日', '一', '二', '三', '四', '五', '六'];
    return Row(
      children: [
        for (final d in dow)
          Expanded(
            child: Center(
              child: Text(d,
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF9AA7C7))),
            ),
          ),
      ],
    );
  }

  Widget _dayCell({
    required int day,
    required String dayStr,
    required bool has,
    required int count,
    required bool isToday,
    required bool isSelected,
  }) {
    Color borderColor = const Color(0x17FFFFFF);
    Color bg = const Color(0x08FFFFFF);
    Color dayColor = const Color(0xFFE8EEFF);

    if (has) {
      borderColor = const Color(0x5900D4FF);
      bg = const Color(0x1F00D4FF);
      dayColor = const Color(0xFF7FE7FF);
    }
    if (isSelected) {
      bg = const Color(0x4700D4FF);
      borderColor = const Color(0xFF00D4FF);
      dayColor = Colors.white;
    }

    return GestureDetector(
      onTap: () => setState(() => _selectedDay = dayStr),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: borderColor,
              width: isSelected ? 1.5 : 1),
          boxShadow: isSelected
              ? [BoxShadow(color: const Color(0xFF00D4FF).withValues(alpha: 0.35), blurRadius: 10)]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$day',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w400,
                    color: dayColor,
                    height: 1.1)),
            if (has)
              Text('$count',
                  style: const TextStyle(
                      fontSize: 8.5, color: Color(0xFF00D4FF), height: 1)),
          ],
        ),
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

  void _backToToday() {
    setState(() {
      final now = DateTime.now();
      _viewDate = DateTime(now.year, now.month);
      _selectedDay = _todayStr();
    });
  }

  // ===== 选中日期内容 =====

  Widget _dayContent(Map<String, List<MemoryCard>> byDay) {
    final day = _selectedDay ?? _todayStr();
    final list = byDay[day] ?? [];
    final isToday = day == _todayStr();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('${_fmtDate(day)} · ${_weekdayCn(day)}',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFE8EEFF))),
            if (isToday) ...[
              const SizedBox(width: 8),
              const Text('今天',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF00D4FF))),
            ],
          ],
        ),
        const SizedBox(height: 12),
        if (list.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0x5900D4FF),
                  style: BorderStyle.none),
              color: const Color(0x0800D4FF),
            ),
            child: Column(
              children: [
                const Text('🌙',
                    style: TextStyle(fontSize: 36)),
                const SizedBox(height: 8),
                Text(isToday ? '今天还没有沉淀记忆' : '这一天没有沉淀记忆',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF00D4FF))),
                const SizedBox(height: 6),
                const Text('说「记一条」，当天的第一份记忆就会出现在这里',
                    style: TextStyle(
                        fontSize: 12.5, color: Color(0xFF9AA7C7))),
              ],
            ),
          )
        else ...[
          _daySummary(list, isToday),
          const SizedBox(height: 12),
          ..._sorted(list).map(_timelineItem),
        ],
      ],
    );
  }

  Widget _daySummary(List<MemoryCard> list, bool isToday) {
    final cats = list.map((c) => c.category).toSet();
    final tags = list.expand((c) => c.tags).toSet();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0x1A00D4FF), Color(0x1A7B61FF)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x4D00D4FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isToday ? '今天 · 总结' : '当日总结',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF00D4FF),
                  letterSpacing: 1)),
          const SizedBox(height: 8),
          Text('沉淀了 ${list.length} 条记忆，覆盖 ${cats.join('、')} 等 ${cats.length} 个主题。',
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFFD6E2FF), height: 1.7)),
          const SizedBox(height: 12),
          Row(
            children: [
              _stat(list.length, '记忆'),
              _stat(cats.length, '主题', color: const Color(0xFF7B61FF)),
              _stat(tags.length, '关键词', color: const Color(0xFF00E5A0)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(int n, String lab, {Color color = const Color(0xFF00D4FF)}) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0x08FFFFFF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0x17FFFFFF)),
        ),
        child: Column(
          children: [
            Text('$n',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: color,
                    height: 1.1)),
            const SizedBox(height: 3),
            Text(lab,
                style: const TextStyle(
                    fontSize: 10.5, color: Color(0xFFA9B6D8))),
          ],
        ),
      ),
    );
  }

  Widget _accessTag(String access) {
    final isAll = access == '所有人';
    final color = isAll ? const Color(0xFF00E5A0) : const Color(0xFFFFB020);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        isAll ? '🔓 所有人' : '🔒 仅个人',
        style: TextStyle(
            fontSize: 9.5, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  List<MemoryCard> _sorted(List<MemoryCard> list) {
    final l = [...list];
    l.sort((a, b) => a.happenedAt.compareTo(b.happenedAt));
    return l;
  }

  Widget _timelineItem(MemoryCard c) {
    final color = Color(colorOf(c.category));
    final time = c.happenedAt.length >= 16 ? c.happenedAt.substring(11, 16) : '';
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Text(time.isEmpty ? '—' : time,
                    style: const TextStyle(
                        fontSize: 10, color: Color(0xFF6B7794))),
                const SizedBox(height: 4),
                Expanded(
                  child: Container(
                    width: 2,
                    color: color.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(c.title,
                            style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFE8EEFF))),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(c.category,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: color)),
                      ),
                      const SizedBox(width: 6),
                      _accessTag(c.access),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(c.summary.isEmpty ? c.content : c.summary,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFC9D4EE),
                          height: 1.6)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDate(String day) {
    final d = DateTime.tryParse(day);
    if (d == null) return day;
    return '${d.year}年${d.month}月${d.day}日';
  }

  String _weekdayCn(String day) {
    final d = DateTime.tryParse(day);
    if (d == null) return '';
    const wd = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    return wd[d.weekday % 7];
  }
}
