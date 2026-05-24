import 'package:flutter/material.dart';

class LatencySparkline extends StatelessWidget {
  final List<double> history;
  final double height;
  final Color color;

  const LatencySparkline({
    super.key,
    required this.history,
    this.height = 40,
    this.color = const Color(0xFFBD00FF),
  });

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text(
            'WAITING FOR TELEMETRY...',
            style: TextStyle(color: Color(0xFF475569), fontSize: 8, fontFamily: 'monospace', fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    return SizedBox(
      height: height,
      child: CustomPaint(
        size: Size.infinite,
        painter: _SparklinePainter(history: history, color: color),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> history;
  final Color color;

  _SparklinePainter({required this.history, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final double step = history.length > 1 ? size.width / (history.length - 1) : size.width;
    double maxVal = 100.0;
    double minVal = 0.0;

    for (var val in history) {
      if (val > maxVal) maxVal = val;
    }

    final double range = maxVal - minVal;
    final List<Offset> points = [];

    for (int i = 0; i < history.length; i++) {
      final double x = i * step;
      final double y = size.height * (1 - ((history[i] - minVal) / range));
      points.add(Offset(x, y.clamp(2.0, size.height - 2.0)));
    }

    final Paint glowPaint = Paint()
      ..color = color.withAlpha(120)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

    final Paint strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final Path path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    // Draw area gradient fill
    final Path areaPath = Path()..moveTo(points.first.dx, size.height);
    for (var point in points) {
      areaPath.lineTo(point.dx, point.dy);
    }
    areaPath.lineTo(points.last.dx, size.height);
    areaPath.close();

    final Paint areaPaint = Paint()
      ..shader = LinearGradient(
        colors: [color.withAlpha(40), color.withAlpha(0)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(areaPath, areaPaint);
    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) {
    return oldDelegate.history != history || oldDelegate.color != color;
  }
}
