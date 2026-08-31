import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'data/memory_repository.dart';
import 'pages/consciousness_page.dart';
import 'pages/knowledge_page.dart';
import 'pages/memory_page.dart';
import 'pages/profile_page.dart';
import 'widgets/device_frame.dart';

void main() => runApp(const ExobrainApp());

class ExobrainApp extends StatelessWidget {
  const ExobrainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '外脑',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF060A18),
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00D4FF),
          brightness: Brightness.dark,
        ),
      ),
      // web 端套手机框模拟移动端；真机运行时不套
      home: kIsWeb ? const DeviceFrame(child: HomeShell()) : const HomeShell(),
    );
  }
}

/// 应用外壳：底部 4 tab，默认落在「对话」（意识体）。
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const _repository = StaticRepository();
  int _tab = 0;

  static const _tabs = <(IconData, IconData, String)>[
    (Icons.chat_bubble_outline, Icons.chat_bubble, '对话'),
    (Icons.access_time, Icons.access_time_filled, '记忆'),
    (Icons.grid_view_outlined, Icons.grid_view, '知识'),
    (Icons.person_outline, Icons.person, '看板'),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const ConsciousnessPage(),
      MemoryPage(repository: _repository),
      KnowledgePage(repository: _repository),
      ProfilePage(repository: _repository),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: _bottomBar(),
    );
  }

  Widget _bottomBar() {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: const Color(0xFF080E1E).withValues(alpha: 0.9),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Row(
            children: List.generate(_tabs.length, (i) {
              final (icon, iconFilled, label) = _tabs[i];
              final on = i == _tab;
              return Expanded(
                child: InkWell(
                  onTap: () => setState(() => _tab = i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        on ? iconFilled : icon,
                        size: 23,
                        color: on ? const Color(0xFF00D4FF) : const Color(0xFF6B7797),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: on ? const Color(0xFF00D4FF) : const Color(0xFF6B7797),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
