import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 手机框外壳 —— 仅在 web 端使用。
/// 把 App 内容限制在 iPhone 尺寸（375×812）的圆角手机框内居中显示，
/// 模拟移动端屏幕（对标 dashboard/mobile.html 的 375×768 手机框）。
class DeviceFrame extends StatelessWidget {
  const DeviceFrame({super.key, required this.child});

  final Widget child;

  // iPhone 标准逻辑尺寸
  static const _frameWidth = 375.0;
  static const _frameHeight = 812.0;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;

    // 屏幕高度减去上下留白；屏幕矮时等比缩放宽度，保持手机比例
    final frameHeight = math.min(_frameHeight, screen.height - 48);
    final scale = frameHeight / _frameHeight;
    final frameWidth = _frameWidth * scale;
    final radius = 44.0 * scale;

    return Scaffold(
      backgroundColor: const Color(0xFF030610),
      body: Center(
        child: Container(
          width: frameWidth,
          height: frameHeight,
          decoration: BoxDecoration(
            color: const Color(0xFF060A18),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: const Color(0x29FFFFFF),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.65),
                blurRadius: 70,
                spreadRadius: 4,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          // 关键：把内部 MediaQuery 的 size 覆盖成手机尺寸，
          // 让页面里所有 MediaQuery.of(context).size 都按手机屏计算
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              size: Size(frameWidth, frameHeight),
              padding: EdgeInsets.zero,
              viewPadding: EdgeInsets.zero,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
