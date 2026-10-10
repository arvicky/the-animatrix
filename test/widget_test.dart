import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:exobrain/main.dart';
import 'package:exobrain/data/account_store.dart';
import 'package:exobrain/widgets/device_frame.dart';

void main() {
  setUp(() {
    // 模拟已登录：ExobrainApp 的 Root 直接进主界面（4 tab），跳过登录/引导
    SharedPreferences.setMockInitialValues({
      'account_session_v1': '{"username":"qb","profile":"animatrix"}',
    });
    AccountStore.reset();
  });

  testWidgets('外壳冒烟：4 tab 存在且可切换', (WidgetTester tester) async {
    await tester.pumpWidget(const ExobrainApp());
    await tester.pump();

    expect(find.text('对话'), findsOneWidget);
    expect(find.text('记忆'), findsOneWidget);
    expect(find.text('知识'), findsOneWidget);
    expect(find.text('看板'), findsOneWidget);

    // 切换到「知识」tab
    await tester.tap(find.text('知识'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('知识卡'), findsOneWidget);

    // 切换到「看板」tab
    await tester.tap(find.text('看板'));
    await tester.pump();
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(find.text('八维画像'), findsOneWidget);
    expect(find.text('身份'), findsOneWidget);
  });

  testWidgets('记忆 tab：日历看板 + 按日期切换', (WidgetTester tester) async {
    await tester.pumpWidget(const ExobrainApp());
    await tester.pump();

    await tester.tap(find.text('记忆'));
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('今天'), findsOneWidget);
    expect(find.textContaining('年'), findsWidgets);
    expect(find.text('日'), findsOneWidget);
    expect(find.textContaining('今天'), findsWidgets);
  });

  testWidgets('对话页在手机框下渲染关键内容', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialAppLike());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('，'), findsWidgets);
    expect(find.text('对话'), findsOneWidget);
    expect(find.text('记忆'), findsOneWidget);
    // 输入框存在（连接失败时禁用但仍在）
    expect(find.byType(TextField), findsOneWidget);
  });
}

class MaterialAppLike extends StatelessWidget {
  const MaterialAppLike({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(brightness: Brightness.dark),
      home: const DeviceFrame(child: HomeShell()),
    );
  }
}
