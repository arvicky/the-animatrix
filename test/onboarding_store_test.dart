import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:exobrain/data/onboarding_store.dart';
import 'package:exobrain/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    OnboardingStore.reset();
    SharedPreferences.setMockInitialValues({});
  });

  test('持久化闭环：未引导 → save → 已引导，数据落盘', () async {
    expect(await OnboardingStore.isCompleted, false);

    await OnboardingStore.save({'name': '曲炳阳', 'gender': '男'});
    expect(await OnboardingStore.isCompleted, true);
    expect(OnboardingStore.cached!['name'], '曲炳阳');

    // 数据真实写入 SharedPreferences（模拟重启后可读）
    final p = await SharedPreferences.getInstance();
    expect(p.getString('onboarding_profile_v1'), contains('曲炳阳'));
  });

  testWidgets('未登录时 Root 显示登录页', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Root()));
    await tester.pump();

    expect(find.text('外脑矩阵'), findsOneWidget);
    expect(find.text('注册新外脑'), findsOneWidget);
  });
}
