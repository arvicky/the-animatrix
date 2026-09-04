import 'package:flutter/material.dart';

import '../data/memory_repository.dart';
import '../models/memory_card.dart';
import '../widgets/glow_background.dart';

/// 「大脑授权」页面 —— 配置把哪些记忆/知识技能分组授权给谁。
///
/// 两大类型：记忆（memory）/ 知识技能（knowledge）。
/// 授权粒度 = 分组（增删改分组），勾选分组即授权该分组下的全部内容。
/// 支持关键词模糊搜索 + 日期范围筛选，帮主人快速看清分组里有什么。
class BrainAuthPage extends StatefulWidget {
  const BrainAuthPage({super.key, required this.repository});

  final MemoryRepository repository;

  @override
  State<BrainAuthPage> createState() => _BrainAuthPageState();
}

class _BrainAuthPageState extends State<BrainAuthPage> {
  List<Exobrain> _targets = []; // 可授权对象（非自己）
  Map<String, List<String>> _groups = {};
  List<Authorization> _auth = [];
  List<MemoryCard> _cards = [];

  int _targetIndex = 0;
  String _type = 'memory'; // memory | knowledge
  String _keyword = '';
  String? _dateFrom; // 日期筛选（起）
  String? _dateTo; // 日期筛选（止）

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final exobrains = await widget.repository.fetchExobrains();
      final groups = await widget.repository.fetchGroups();
      final auth = await widget.repository.fetchAuthorization();
      final cards = await widget.repository.fetchCards();
      if (!mounted) return;
      setState(() {
        _targets = exobrains.where((e) => e.profile != 'animatrix').toList();
        _groups = groups;
        _auth = auth;
        _cards = cards;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败：$e')));
    }
  }

  // ===== 当前对象 =====
  Exobrain? get _target => _targets.isEmpty ? null : _targets[_targetIndex];

  String get _pair => '曲炳阳 → ${_target?.owner ?? ''}';

  Authorization? get _currentAuth {
    for (final a in _auth) {
      if (a.pair == _pair) return a;
    }
    return null;
  }

  /// 当前类型下，已授权的分组集合
  Set<String> get _selected {
    final g = _currentAuth?.grant ?? const {};
    return (g[_type] ?? const []).toSet();
  }

  /// 当前类型下的全部分组
  List<String> get _typeGroups => _groups[_type] ?? const [];

  /// 当前类型下的卡片（记忆=生活记忆分组，知识技能=其余分组）
  List<MemoryCard> get _typeCards {
    final groups = _typeGroups.toSet();
    return _cards.where((c) => groups.contains(c.category)).toList();
  }

  /// 按关键词 + 日期筛选后的卡片（用于预览分组内容）
  List<MemoryCard> get _filteredCards {
    final kw = _keyword.trim();
    var list = _typeCards;
    if (kw.isNotEmpty) {
      list = list.where((c) =>
          c.title.contains(kw) ||
          c.content.contains(kw) ||
          c.summary.contains(kw) ||
          c.tags.any((t) => t.contains(kw))).toList();
    }
    if (_dateFrom != null) {
      list = list.where((c) => c.happenedAt.compareTo(_dateFrom!) >= 0).toList();
    }
    if (_dateTo != null) {
      list = list.where((c) => c.happenedAt.compareTo('${_dateTo!}~') <= 0).toList();
    }
    return list;
  }

  Future<void> _save() async {
    final target = _target;
    if (target == null) return;
    setState(() => _saving = true);
    try {
      final current = _currentAuth?.grant ?? {};
      final grant = Map<String, List<String>>.from(current);
      grant[_type] = _selected.toList()..sort();
      await widget.repository.saveAuth(_pair, grant);
      // 刷新本地 auth
      final auth = await widget.repository.fetchAuthorization();
      if (!mounted) return;
      setState(() {
        _auth = auth;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ 已保存授权')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('保存失败：$e')));
    }
  }

  // ===== 分组管理 =====
  Future<void> _addGroup() async {
    final name = await _promptName('新增分组', '');
    if (name == null || name.isEmpty) return;
    await widget.repository.saveGroup('add', _type, name);
    _reloadGroups();
  }

  Future<void> _renameGroup(String oldName) async {
    final name = await _promptName('重命名分组', oldName);
    if (name == null || name.isEmpty) return;
    await widget.repository.saveGroup('rename', _type, oldName, newName: name);
    _reloadGroups();
  }

  Future<void> _removeGroup(String name) async {
    await widget.repository.saveGroup('remove', _type, name);
    _reloadGroups();
  }

  Future<void> _reloadGroups() async {
    final groups = await widget.repository.fetchGroups();
    if (!mounted) return;
    setState(() => _groups = groups);
  }

  Future<String?> _promptName(String title, String initial) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0C1428),
        title: Text(title, style: const TextStyle(color: Color(0xFFE8EEFF))),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Color(0xFFE8EEFF)),
          decoration: const InputDecoration(
            hintText: '分组名称',
            hintStyle: TextStyle(color: Color(0xFF6B7794)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('确定')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060A18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF060A18),
        title: const Text('大脑授权',
            style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFE8EEFF))),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : GlowBackground(child: _body()),
    );
  }

  Widget _body() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _targetSelector(),
        const SizedBox(height: 16),
        _typeTabs(),
        const SizedBox(height: 16),
        _searchBar(),
        const SizedBox(height: 16),
        _groupSection(),
        const SizedBox(height: 12),
        _previewSection(),
      ],
    );
  }

  Widget _targetSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('授权给谁',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF9AA7C7))),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [
            for (var i = 0; i < _targets.length; i++)
              ChoiceChip(
                label: Text('${_targets[i].owner}${_targets[i].nickname.isNotEmpty && _targets[i].nickname != '—' ? '（${_targets[i].nickname}）' : ''}'),
                selected: i == _targetIndex,
                onSelected: (_) => setState(() => _targetIndex = i),
                selectedColor: const Color(0xFF00D4FF),
                labelStyle: TextStyle(
                    color: i == _targetIndex
                        ? const Color(0xFF061428)
                        : const Color(0xFFC9D4EE),
                    fontWeight: FontWeight.w700),
                backgroundColor: const Color(0x14FFFFFF),
              ),
          ],
        ),
      ],
    );
  }

  Widget _typeTabs() {
    const tabs = [
      ('memory', '记忆'),
      ('knowledge', '知识技能'),
    ];
    return Row(
      children: [
        for (final (key, label) in tabs)
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _type = key),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _type == key
                      ? const Color(0x2600D4FF)
                      : const Color(0x08FFFFFF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: _type == key
                          ? const Color(0xFF00D4FF)
                          : const Color(0x17FFFFFF)),
                ),
                child: Center(
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _type == key
                              ? const Color(0xFF00D4FF)
                              : const Color(0xFF9AA7C7))),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _searchBar() {
    return Column(
      children: [
        TextField(
          onChanged: (v) => setState(() => _keyword = v),
          style: const TextStyle(color: Color(0xFFE8EEFF)),
          decoration: InputDecoration(
            hintText: '关键词模糊搜索（标题/内容/标签）',
            hintStyle: const TextStyle(color: Color(0xFF6B7794)),
            prefixIcon: const Icon(Icons.search, color: Color(0xFF6B7794)),
            filled: true,
            fillColor: const Color(0x0AFFFFFF),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _dateChip(_dateFrom, '起始日期'),
            const SizedBox(width: 8),
            _dateChip(_dateTo, '截止日期'),
            const Spacer(),
            if (_dateFrom != null || _dateTo != null)
              TextButton(
                  onPressed: () => setState(() {
                        _dateFrom = null;
                        _dateTo = null;
                      }),
                  child: const Text('清除日期')),
          ],
        ),
      ],
    );
  }

  Widget _dateChip(String? val, String label) {
    return GestureDetector(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (d != null) {
          final s = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
          setState(() {
            if (label == '起始日期') {
              _dateFrom = s;
            } else {
              _dateTo = s;
            }
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x5900D4FF)),
        ),
        child: Text(
          val == null ? label : '${label.substring(0, 2)}:$val',
          style: TextStyle(
              fontSize: 11.5,
              color: val == null ? const Color(0xFF6B7794) : const Color(0xFF00D4FF)),
        ),
      ),
    );
  }

  Widget _groupSection() {
    final selected = _selected;
    final groups = _typeGroups;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('授权分组（勾选即授权该组全部内容）',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF9AA7C7))),
            const Spacer(),
            TextButton.icon(
              onPressed: _addGroup,
              icon: const Icon(Icons.add, size: 16, color: Color(0xFF00D4FF)),
              label: const Text('新增分组',
                  style: TextStyle(fontSize: 12, color: Color(0xFF00D4FF))),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (groups.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0x08FFFFFF)),
            child: const Center(
                child: Text('暂无分组，点右上角「新增分组」',
                    style: TextStyle(color: Color(0xFF6B7794)))),
          )
        else
          ...groups.map((g) => _groupTile(g, selected.contains(g))),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D4FF),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(_saving ? '保存中…' : '保存授权',
                style: const TextStyle(
                    color: Color(0xFF061428),
                    fontWeight: FontWeight.w900,
                    fontSize: 15)),
          ),
        ),
      ],
    );
  }

  Widget _groupTile(String name, bool checked) {
    final count = _cards.where((c) => c.category == name).length;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: checked ? const Color(0x1F00D4FF) : const Color(0x08FFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: checked ? const Color(0xFF00D4FF) : const Color(0x17FFFFFF)),
      ),
      child: Row(
        children: [
          Checkbox(
            value: checked,
            activeColor: const Color(0xFF00D4FF),
            onChanged: (v) => setState(() {
              final s = _selected;
              if (v == true) {
                s.add(name);
              } else {
                s.remove(name);
              }
              // 本地即时更新当前 auth 的 grant
              _applyLocalGrant(s);
            }),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFE8EEFF))),
                Text('$count 条内容',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF6B7794))),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF6B7794)),
            onPressed: () => _renameGroup(name),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFFF8FA0)),
            onPressed: () => _removeGroup(name),
          ),
        ],
      ),
    );
  }

  /// 勾选变化时，本地同步当前 auth 的 grant（保存时才真正写后端）
  void _applyLocalGrant(Set<String> selected) {
    final target = _target;
    if (target == null) return;
    final idx = _auth.indexWhere((a) => a.pair == _pair);
    if (idx == -1) return;
    final a = _auth[idx];
    final grant = Map<String, List<String>>.from(a.grant);
    grant[_type] = selected.toList()..sort();
    _auth[idx] = Authorization(
        pair: a.pair, resource: a.resource, status: a.status, grant: grant);
  }

  Widget _previewSection() {
    final list = _filteredCards;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('内容预览（${list.length} 条）',
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF9AA7C7))),
        const SizedBox(height: 8),
        if (list.isEmpty)
          const Text('没有匹配的内容',
              style: TextStyle(color: Color(0xFF6B7794), fontSize: 12))
        else
          ...list.take(20).map(_previewCard),
      ],
    );
  }

  Widget _previewCard(MemoryCard c) {
    final color = Color(colorOf(c.category));
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
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
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFE8EEFF))),
              ),
              Text(c.happenedAt.isEmpty ? '' : c.happenedAt.substring(0, 10),
                  style: TextStyle(fontSize: 10, color: color)),
            ],
          ),
          const SizedBox(height: 4),
          Text(c.summary.isEmpty ? c.content : c.summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 11.5, color: Color(0xFFC9D4EE), height: 1.5)),
        ],
      ),
    );
  }
}
