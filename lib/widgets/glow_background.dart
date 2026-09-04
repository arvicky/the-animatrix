import 'package:flutter/material.dart';

/// 共享视觉组件 —— 对标 dashboard 的 glow 光晕背景 + 卡片高亮线。
class GlowBackground extends StatelessWidget {
  const GlowBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // ponytail: 干净纯色背景，去掉光晕图案（影响看字）
    return ColoredBox(
      color: const Color(0xFF060A18),
      child: child,
    );
  }
}

/// 卡片顶部的高亮渐变线（复刻 dashboard .card::before）
class TopAccentLine extends StatelessWidget {
  const TopAccentLine({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0),
            color,
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}
