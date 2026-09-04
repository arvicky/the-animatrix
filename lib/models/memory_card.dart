/// 外脑数据模型 —— 双时间轴记忆卡 + 外脑 + 授权。
///
/// 字段语义与 `E:\animatrix\dashboard\data.js` 严格对应：
///   happened_at  事件发生时间（客观世界）
///   created_at   记忆形成时间（第一次沉淀）
///   updated_at   记忆迭代时间（最近修正）
///   version/history 留痕迭代（改一条 = 记一笔，而非覆盖）
library;

class MemoryCard {
  final String id;
  final String title;
  final String category;
  final List<String> tags;
  final String content;
  final String summary;
  final String happenedAt;
  final String day;
  final String era;
  final String createdAt;
  final String updatedAt;
  final int version;
  final List<String> history;
  final double strength;
  final int salience;
  final List<String> links;
  final List<String> contextTags;

  const MemoryCard({
    required this.id,
    required this.title,
    required this.category,
    required this.tags,
    required this.content,
    required this.summary,
    required this.happenedAt,
    required this.day,
    required this.era,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    required this.history,
    required this.strength,
    required this.salience,
    required this.links,
    required this.contextTags,
  });

  factory MemoryCard.fromMap(Map<String, dynamic> m) => MemoryCard(
        id: m['id'] as String? ?? '',
        title: m['title'] as String? ?? '',
        category: m['category'] as String? ?? '未分类',
        tags: (m['tags'] as List?)?.cast<String>() ?? const [],
        content: m['content'] as String? ?? '',
        summary: m['summary'] as String? ?? '',
        happenedAt: m['happened_at'] as String? ?? '',
        day: m['day'] as String? ?? '',
        era: m['era'] as String? ?? '',
        createdAt: m['created_at'] as String? ?? '',
        updatedAt: m['updated_at'] as String? ?? '',
        version: (m['version'] as num?)?.toInt() ?? 1,
        history: (m['history'] as List?)?.cast<String>() ?? const [],
        strength: (m['strength'] as num?)?.toDouble() ?? 1.0,
        salience: (m['salience'] as num?)?.toInt() ?? 5,
        links: (m['links'] as List?)?.cast<String>() ?? const [],
        contextTags: (m['context_tags'] as List?)?.cast<String>() ?? const [],
      );
}

class Exobrain {
  final String profile;
  final String owner;
  final String nickname;
  final String dir;
  final String note;

  const Exobrain({
    required this.profile,
    required this.owner,
    required this.nickname,
    required this.dir,
    required this.note,
  });

  factory Exobrain.fromMap(Map<String, String> m) => Exobrain(
        profile: m['profile'] ?? '',
        owner: m['owner'] ?? '',
        nickname: m['nickname'] ?? '',
        dir: m['dir'] ?? '',
        note: m['note'] ?? '',
      );
}

/// 授权状态：跨外脑调取记忆/知识前必须「已授权」。
enum AuthStatus {
  pending('待授权'),
  granted('已授权'),
  denied('已拒绝');

  final String label;
  const AuthStatus(this.label);

  static AuthStatus from(String s) => switch (s) {
        '已授权' => AuthStatus.granted,
        '已拒绝' => AuthStatus.denied,
        _ => AuthStatus.pending,
      };
}

class Authorization {
  final String pair;
  final String resource;
  final AuthStatus status;
  final Map<String, List<String>> grant; // 大脑授权：{memory:[分组...], knowledge:[分组...]}

  const Authorization({
    required this.pair,
    required this.resource,
    required this.status,
    this.grant = const {},
  });

  factory Authorization.fromMap(Map<String, dynamic> m) {
    final g = <String, List<String>>{};
    final raw = m['grant'];
    if (raw is Map) {
      raw.forEach((k, v) {
        g[k.toString()] = (v as List?)?.map((e) => e.toString()).toList() ?? [];
      });
    }
    return Authorization(
      pair: m['pair'] ?? '',
      resource: m['resource'] ?? '',
      status: AuthStatus.from(m['status'] ?? '待授权'),
      grant: g,
    );
  }
}

/// 分类 → 颜色（与 dashboard 一致）
const Map<String, int> categoryColor = {
  '外脑设计': 0xFFFF5C7A,
  '工作经验': 0xFF00D4FF,
  '踩坑复盘': 0xFF7B61FF,
  '生活记忆': 0xFF00E5A0,
  '灵光一闪': 0xFFFFB020,
};

int colorOf(String category) => categoryColor[category] ?? 0xFF00D4FF;
