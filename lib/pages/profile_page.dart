import 'package:flutter/material.dart';

import '../data/memory_repository.dart';
import '../models/memory_card.dart';
import '../models/person_profile.dart';
import '../widgets/glow_background.dart';

/// 「看板」tab —— 个人看板。
/// 顶部：基本信息（前期配置，含必填标注）
/// 中部：八维度画像（可编辑，空维度提示「待补全」）
/// 底部：外脑矩阵 + 授权分享
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.repository});

  final MemoryRepository repository;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late Future<(List<Exobrain>, List<Authorization>)> _future;
  late List<BasicField> _basics;
  late List<ProfileDimension> _dims;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _basics = List.of(qbyProfile.basics);
    _dims = qbyProfile.dimensions
        .map((d) => ProfileDimension(
            title: d.title,
            icon: d.icon,
            color: d.color,
            items: List.of(d.items)))
        .toList();
  }

  Future<(List<Exobrain>, List<Authorization>)> _load() async {
    final eb = await widget.repository.fetchExobrains();
    final au = await widget.repository.fetchAuthorization();
    return (eb, au);
  }

  Future<void> _editDimension(int index) async {
    final d = _dims[index];
    await showDialog(
      context: context,
      builder: (_) => _DimensionEditor(
        dimension: d,
        items: List.of(d.items),
        onSave: (newItems) {
          setState(() {
            _dims[index] = ProfileDimension(
                title: d.title,
                icon: d.icon,
                color: d.color,
                items: newItems);
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlowBackground(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _header(),
          const SizedBox(height: 20),
          _sectionTitle('基本信息'),
          const SizedBox(height: 6),
          const Text('前期配置 · 必填项不可为空，外脑会据此识别你。',
              style: TextStyle(fontSize: 12, color: Color(0xFF9AA7C7))),
          const SizedBox(height: 12),
          _basicInfoCard(),
          const SizedBox(height: 24),
          _sectionTitle('八维画像'),
          const SizedBox(height: 6),
          const Text('外脑会持续补全这些维度，还原一个完整的你。',
              style: TextStyle(fontSize: 12, color: Color(0xFF9AA7C7))),
          const SizedBox(height: 12),
          ...List.generate(_dims.length, (i) => _dimensionCard(i)),
          const SizedBox(height: 24),
          FutureBuilder<(List<Exobrain>, List<Authorization>)>(
            future: _future,
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final (exobrains, auth) = snap.data!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('外脑矩阵'),
                  const SizedBox(height: 10),
                  ...exobrains.map(_exobrainCard),
                  const SizedBox(height: 24),
                  _sectionTitle('授权分享'),
                  const SizedBox(height: 6),
                  const Text('跨外脑调取记忆 / 知识库，须先征得对方同意。',
                      style: TextStyle(
                          fontSize: 12, color: Color(0xFF9AA7C7))),
                  const SizedBox(height: 12),
                  _authList(auth),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0x1400D4FF), Color(0x127B61FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x4000D4FF)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF7FE7FF), Color(0xFF00D4FF), Color(0xFF0650C8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Center(
              child: Text('曲',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF061428))),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(qbyProfile.name,
                    style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFE8EEFF))),
                const SizedBox(height: 4),
                Text(qbyProfile.greeting,
                    style: const TextStyle(
                        fontSize: 12.5, color: Color(0xFFA9B6D8))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) {
    return Text(t,
        style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: Color(0xFFE8EEFF)));
  }

  /// 基本信息卡片：字段列表 + 必填徽标
  Widget _basicInfoCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0x0BFFFFFF), Color(0x05FFFFFF)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x17FFFFFF)),
      ),
      child: Column(
        children: [
          for (final f in _basics) _basicField(f),
        ],
      ),
    );
  }

  Widget _basicField(BasicField f) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x0FFFFFFF))),
      ),
      child: Row(
        children: [
          Text(f.label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF9AA7C7))),
          const SizedBox(width: 10),
          if (f.required)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0x22FF5C7A),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0x66FF5C7A)),
              ),
              child: const Text('必填',
                  style: TextStyle(
                      fontSize: 9.5,
                      color: Color(0xFFFF8FA0),
                      fontWeight: FontWeight.w700)),
            ),
          const Spacer(),
          Text(f.value,
              style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFE8EEFF))),
        ],
      ),
    );
  }

  Widget _dimensionCard(int i) {
    final d = _dims[i];
    final color = Color(d.color);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0x0BFFFFFF), Color(0x05FFFFFF)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x17FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(d.icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(d.title,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: color)),
              const Spacer(),
              Text(d.items.isEmpty ? '待补全' : '${d.items.length} 项',
                  style: TextStyle(
                      fontSize: 10.5,
                      color: d.items.isEmpty
                          ? const Color(0xFFFFB020)
                          : const Color(0xFF6B7794))),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _editDimension(i),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_outlined, size: 12, color: color),
                      const SizedBox(width: 4),
                      Text('编辑',
                          style: TextStyle(
                              fontSize: 11,
                              color: color,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (d.items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text('这个维度还没采集，点「编辑」补充，或在对话里告诉外脑。',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF6B7794), height: 1.5)),
            )
          else
            ...d.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 4,
                      height: 4,
                      margin: const EdgeInsets.only(top: 7),
                      decoration: BoxDecoration(
                          shape: BoxShape.circle, color: color),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(item,
                          style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFFC9D4EE),
                              height: 1.55)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _exobrainCard(Exobrain e) {
    const colors = [Color(0xFF00D4FF), Color(0xFF7B61FF), Color(0xFF00E5A0)];
    final color = colors[e.profile.hashCode.abs() % 3];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Text(e.profile,
              style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                  color: color)),
          const SizedBox(width: 10),
          if (e.nickname.isNotEmpty && e.nickname != '—')
            Text('昵称·${e.nickname}',
                style: const TextStyle(
                    fontSize: 11.5, color: Color(0xFF9AA7C7))),
          const Spacer(),
          Text(e.owner,
              style: const TextStyle(
                  fontSize: 12.5, color: Color(0xFFC9D4EE))),
        ],
      ),
    );
  }

  Widget _authList(List<Authorization> auth) {
    return Column(
      children: [for (final a in auth) _authRow(a)],
    );
  }

  Widget _authRow(Authorization a) {
    final (color, bg) = switch (a.status) {
      AuthStatus.granted => (const Color(0xFF00E5A0), const Color(0x2600E5A0)),
      AuthStatus.denied => (const Color(0xFFFF5C7A), const Color(0x26FF5C7A)),
      AuthStatus.pending => (const Color(0xFFFFB020), const Color(0x26FFB020)),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0x0BFFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x17FFFFFF)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.pair,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFE8EEFF))),
                const SizedBox(height: 2),
                Text(a.resource,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF9AA7C7))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color),
            ),
            child: Text(a.status.label,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ),
        ],
      ),
    );
  }
}

/// 维度编辑弹窗：列出条目（可删）+ 底部输入框（可加）。
class _DimensionEditor extends StatefulWidget {
  const _DimensionEditor({
    required this.dimension,
    required this.items,
    required this.onSave,
  });

  final ProfileDimension dimension;
  final List<String> items;
  final void Function(List<String>) onSave;

  @override
  State<_DimensionEditor> createState() => _DimensionEditorState();
}

class _DimensionEditorState extends State<_DimensionEditor> {
  late List<String> _items;
  final TextEditingController _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.items);
  }

  void _add() {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _items.add(t);
      _ctrl.clear();
    });
  }

  void _remove(int i) {
    setState(() => _items.removeAt(i));
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(widget.dimension.color);
    return AlertDialog(
      backgroundColor: const Color(0xFF0E1B3D),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Row(
        children: [
          Icon(widget.dimension.icon, size: 20, color: color),
          const SizedBox(width: 8),
          Text('编辑 · ${widget.dimension.title}',
              style: TextStyle(fontSize: 16, color: color)),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_items.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('还没有条目，在下方添加第一条。',
                    style: TextStyle(fontSize: 12, color: Color(0xFF9AA7C7))),
              ),
            ...List.generate(_items.length, (i) {
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0x0DFFFFFF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0x17FFFFFF)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(_items[i],
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFFE8EEFF))),
                    ),
                    GestureDetector(
                      onTap: () => _remove(i),
                      child: const Icon(Icons.close,
                          size: 16, color: Color(0xFFFF8FA0)),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFFE8EEFF)),
                    decoration: InputDecoration(
                      hintText: '新增一条…',
                      hintStyle:
                          const TextStyle(color: Color(0xFF6B7794)),
                      filled: true,
                      fillColor: const Color(0x0DFFFFFF),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _add,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.add, size: 18, color: color),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消',
              style: TextStyle(color: Color(0xFF9AA7C7))),
        ),
        TextButton(
          onPressed: () {
            widget.onSave(_items);
            Navigator.pop(context);
          },
          child: Text('保存', style: TextStyle(color: color)),
        ),
      ],
    );
  }
}
