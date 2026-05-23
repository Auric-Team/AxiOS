import 'package:flutter/material.dart';

class CyberCard extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final List<Color> borderGlowColors;

  const CyberCard({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.borderGlowColors = const [Color(0xFF1E293B), Color(0xFF0F172A)],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0x990A0E17), // Glassmorphic translucent dark background
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (borderGlowColors.first).withAlpha((255 * 0.12).round()),
            blurRadius: 24,
            spreadRadius: 1,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _GradientBorderPainter(
          gradient: LinearGradient(
            colors: borderGlowColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          strokeWidth: 1.5,
          borderRadius: 20,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(22),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _GradientBorderPainter extends CustomPainter {
  final Gradient gradient;
  final double strokeWidth;
  final double borderRadius;

  _GradientBorderPainter({
    required this.gradient,
    required this.strokeWidth,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final RRect outerRRect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(borderRadius),
    );
    final RRect innerRRect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth),
      Radius.circular(borderRadius - strokeWidth),
    );

    final Paint paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;

    canvas.drawDRRect(outerRRect, innerRRect, paint);
  }

  @override
  bool shouldRepaint(_GradientBorderPainter oldDelegate) {
    return oldDelegate.gradient != gradient ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.borderRadius != borderRadius;
  }
}
