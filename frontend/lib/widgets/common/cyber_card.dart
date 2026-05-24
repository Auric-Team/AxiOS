import 'dart:ui';
import 'package:flutter/material.dart';

class CyberCard extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final List<Color> borderGlowColors;
  final bool showCornerBrackets;

  const CyberCard({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.borderGlowColors = const [Color(0xFF1E293B), Color(0xFF0F172A)],
    this.showCornerBrackets = true,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: const Color(0x66070B13), // Glassmorphism translucent backdrop
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withAlpha(5), width: 0.5),
            boxShadow: [
              BoxShadow(
                color: (borderGlowColors.first).withAlpha((255 * 0.05).round()),
                blurRadius: 20,
                spreadRadius: 0.5,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: CustomPaint(
            painter: _CyberBorderAndBracketsPainter(
              gradient: LinearGradient(
                colors: borderGlowColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              strokeWidth: 1.0,
              borderRadius: 20,
              showBrackets: showCornerBrackets,
            ),
            child: Padding(
              padding: padding ?? const EdgeInsets.all(22),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _CyberBorderAndBracketsPainter extends CustomPainter {
  final Gradient gradient;
  final double strokeWidth;
  final double borderRadius;
  final bool showBrackets;

  _CyberBorderAndBracketsPainter({
    required this.gradient,
    required this.strokeWidth,
    required this.borderRadius,
    required this.showBrackets,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final RRect outerRRect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));
    final RRect innerRRect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth),
      Radius.circular(borderRadius - strokeWidth),
    );

    final Paint borderPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;

    // Draw the subtle background border
    canvas.drawDRRect(outerRRect, innerRRect, borderPaint);

    if (showBrackets) {
      // Draw neon corner brackets for premium cyberpunk HUD aesthetic
      final Paint bracketPaint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;

      const double bracketLen = 14.0;
      final double offset = strokeWidth / 2;

      // Top Left Corner
      final Path tlPath = Path()
        ..moveTo(offset, offset + bracketLen)
        ..lineTo(offset, offset)
        ..lineTo(offset + bracketLen, offset);
      canvas.drawPath(tlPath, bracketPaint);

      // Top Right Corner
      final Path trPath = Path()
        ..moveTo(size.width - offset - bracketLen, offset)
        ..lineTo(size.width - offset, offset)
        ..lineTo(size.width - offset, offset + bracketLen);
      canvas.drawPath(trPath, bracketPaint);

      // Bottom Left Corner
      final Path blPath = Path()
        ..moveTo(offset, size.height - offset - bracketLen)
        ..lineTo(offset, size.height - offset)
        ..lineTo(offset + bracketLen, size.height - offset);
      canvas.drawPath(blPath, bracketPaint);

      // Bottom Right Corner
      final Path brPath = Path()
        ..moveTo(size.width - offset - bracketLen, size.height - offset)
        ..lineTo(size.width - offset, size.height - offset)
        ..lineTo(size.width - offset, size.height - offset - bracketLen);
      canvas.drawPath(brPath, bracketPaint);
    }
  }

  @override
  bool shouldRepaint(_CyberBorderAndBracketsPainter oldDelegate) {
    return oldDelegate.gradient != gradient ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.showBrackets != showBrackets;
  }
}
