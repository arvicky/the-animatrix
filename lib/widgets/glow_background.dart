import 'package:flutter/material.dart';

/// 共享视觉组件 —— 对标 dashboard 的 glow 光晕背景 + 卡片高亮线。
class GlowBackground extends StatelessWidget {
  const GlowBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 三个光晕，复刻 dashboard .glow 的模糊大色块
        Positioned(
          top: -160,
          left: -120,
          child: _glow(const Color(0xFF00D4FF), 420),
        ),
        Positioned(
          top: 200,
          right: -140,
          child: _glow(const Color(0xFF7B61FF), 360),
        ),
        Positioned(
          bottom: -120,
          left: 60,
          child: _glow(const Color(0xFF00E5A0), 340),
        ),
        Positioned.fill(child: child),
      ],
    );
  }

  Widget _glow(Color c, double size) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: c.withValues(alpha: 0.16),
        ),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.withValues(alpha: 0.1),
          ),
        ),
      ),
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
