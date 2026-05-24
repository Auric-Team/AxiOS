import 'dart:math';
import 'package:flutter/material.dart';

class NeonDoughnutChart extends StatefulWidget {
  final Map<String, double> data; // category -> value
  final Map<String, Color> colors;

  const NeonDoughnutChart({
    super.key,
    required this.data,
    required this.colors,
  });

  @override
  State<NeonDoughnutChart> createState() => _NeonDoughnutChartState();
}

class _NeonDoughnutChartState extends State<NeonDoughnutChart> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant NeonDoughnutChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.reset();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (ctx, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: _DoughnutPainter(
            data: widget.data,
            colors: widget.colors,
            progress: _animation.value,
          ),
        );
      },
    );
  }
}

class _DoughnutPainter extends CustomPainter {
  final Map<String, double> data;
  final Map<String, Color> colors;
  final double progress;

  _DoughnutPainter({
    required this.data,
    required this.colors,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double total = data.values.fold(0, (prev, element) => prev + element);
    if (total == 0) return;

    final double side = min(size.width, size.height);
    final double radius = side / 2;
    final double strokeWidth = 10.0;
    final Offset center = Offset(size.width / 2, size.height / 2);
    final Rect rect = Rect.fromCircle(center: center, radius: radius - strokeWidth);

    double startAngle = -pi / 2;

    // Draw background track
    final Paint trackPaint = Paint()
      ..color = const Color(0xFF1E293B).withAlpha(100)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius - strokeWidth, trackPaint);

    data.forEach((key, value) {
      final double sweepAngle = (value / total) * 2 * pi * progress;
      final Color color = colors[key] ?? Colors.grey;

      // Glow paint
      final Paint glowPaint = Paint()
        ..color = color.withAlpha(120)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 4
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
      canvas.drawArc(rect, startAngle, sweepAngle, false, glowPaint);

      // Core paint
      final Paint segmentPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, startAngle, sweepAngle, false, segmentPaint);

      startAngle += sweepAngle;
    });
  }

  @override
  bool shouldRepaint(_DoughnutPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.colors != colors ||
        oldDelegate.progress != progress;
  }
}
