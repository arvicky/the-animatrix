// 抽取外脑真实数据 → 生成 Dart seed 数据
// 用法：node tools/export_seed.mjs  （在项目根目录运行）
// 读 E:\animatrix\dashboard\data.js 和 console_data.js，输出 lib/data/seed_data.dart
import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const DASH = 'E:\\animatrix\\dashboard\\';
const OUT = join(__dirname, '..', 'lib', 'data', 'seed_data.dart');

// 用 new Function 执行 window.__DATA__ = {...} 得到对象
function loadJsObject(path) {
  const code = readFileSync(path, 'utf-8');
  let obj = null;
  const fn = new Function('window', code + '\n;return window.__DATA__ || window.__CONSOLE__;');
  obj = fn({});
  return obj;
}

const data = loadJsObject(DASH + 'data.js');
const cons = loadJsObject(DASH + 'console_data.js');

// ---- 记忆卡（双时间轴 schema 完整保留）----
const skills = (data.skills || []).map(s => ({
  id: s.id, title: s.title, category: s.category, tags: s.tags || [],
  content: s.content, summary: s.summary, happened_at: s.happened_at, day: s.day,
  era: s.era, created_at: s.created_at, updated_at: s.updated_at,
  version: s.version, history: s.history || [], strength: s.strength,
  salience: s.salience, links: s.links || [], context_tags: s.context_tags || [],
}));

// ---- 外脑清单 + 授权 ----
const exobrains = (cons.exobrains || []).map(e => ({
  profile: e.profile, owner: e.owner, nickname: e.nickname, dir: e.dir, note: e.note,
}));
const authorization = (cons.authorization || []).map(a => ({
  pair: a.pair, resource: a.resource, status: a.status, scope: (a.scope || []).join(','),
}));

// 逃逸 Dart 字符串
const esc = s => String(s == null ? '' : s)
  .replace(/\\/g, '\\\\').replace(/\$/g, '\\$')
  .replace(/"/g, '\\"').replace(/\n/g, '\\n');

const q = s => `"${esc(s)}"`;
const arr = xs => `[${(xs || []).map(x => q(x)).join(', ')}]`;

// 生成 Dart 代码
const lines = [];
lines.push('// 由 tools/export_seed.mjs 自动生成 —— 勿手改，改数据后重跑脚本');
lines.push('// 数据源：E:\\animatrix\\dashboard\\data.js + console_data.js');
lines.push('');
lines.push('class SeedData {');
lines.push('  static const metaUpdated = ' + q(data.meta?.updated) + ';');
lines.push('  static const exobrainVersion = ' + q(data.meta?.version) + ';');
lines.push('');

// 记忆卡
lines.push('  static const List<Map<String, dynamic>> memoryCards = [');
for (const s of skills) {
  lines.push('    {');
  lines.push('      ' + q('id') + ': ' + q(s.id) + ',');
  lines.push('      ' + q('title') + ': ' + q(s.title) + ',');
  lines.push('      ' + q('category') + ': ' + q(s.category) + ',');
  lines.push('      ' + q('tags') + ': ' + arr(s.tags) + ',');
  lines.push('      ' + q('content') + ': ' + q(s.content) + ',');
  lines.push('      ' + q('summary') + ': ' + q(s.summary) + ',');
  lines.push('      ' + q('happened_at') + ': ' + q(s.happened_at) + ',');
  lines.push('      ' + q('day') + ': ' + q(s.day) + ',');
  lines.push('      ' + q('era') + ': ' + q(s.era) + ',');
  lines.push('      ' + q('created_at') + ': ' + q(s.created_at) + ',');
  lines.push('      ' + q('updated_at') + ': ' + q(s.updated_at) + ',');
  lines.push('      ' + q('version') + ': ' + String(s.version) + ',');
  lines.push('      ' + q('history') + ': ' + arr((s.history || []).map(h => h.at + '：' + h.note)) + ',');
  lines.push('      ' + q('strength') + ': ' + String(s.strength) + ',');
  lines.push('      ' + q('salience') + ': ' + String(s.salience) + ',');
  lines.push('      ' + q('links') + ': ' + arr(s.links) + ',');
  lines.push('      ' + q('context_tags') + ': ' + arr(s.context_tags) + ',');
  lines.push('    },');
}
lines.push('  ];');
lines.push('');

// 外脑清单
lines.push('  static const List<Map<String, String>> exobrains = [');
for (const e of exobrains) {
  lines.push('    {' + ['profile', 'owner', 'nickname', 'dir', 'note']
    .map(k => `${q(k)}: ${q(e[k])}`).join(', ') + '},');
}
lines.push('  ];');
lines.push('');

// 授权
lines.push('  static const List<Map<String, String>> authorization = [');
for (const a of authorization) {
  lines.push('    {' + ['pair', 'resource', 'status', 'scope']
    .map(k => `${q(k)}: ${q(a[k])}`).join(', ') + '},');
}
lines.push('  ];');
lines.push('}');
lines.push('');

writeFileSync(OUT, lines.join('\n'), 'utf-8');
console.log('已生成 ' + OUT);
console.log('  记忆卡 ' + skills.length + ' 张 · 外脑 ' + exobrains.length + ' 个 · 授权 ' + authorization.length + ' 条');
