import 'package:flutter/material.dart';

class NeonLineChart extends StatefulWidget {
  final List<double> data;
  final List<String> labels;
  final Color glowColor;

  const NeonLineChart({
    super.key,
    required this.data,
    required this.labels,
    this.glowColor = const Color(0xFF00FFCC),
  });

  @override
  State<NeonLineChart> createState() => _NeonLineChartState();
}

class _NeonLineChartState extends State<NeonLineChart> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant NeonLineChart oldWidget) {
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
          painter: _NeonLinePainter(
            data: widget.data,
            labels: widget.labels,
            progress: _animation.value,
            glowColor: widget.glowColor,
          ),
        );
      },
    );
  }
}

class _NeonLinePainter extends CustomPainter {
  final List<double> data;
  final List<String> labels;
  final double progress;
  final Color glowColor;

  _NeonLinePainter({
    required this.data,
    required this.labels,
    required this.progress,
    required this.glowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final double paddingLeft = 32.0;
    final double paddingRight = 16.0;
    final double paddingTop = 20.0;
    final double paddingBottom = 28.0;

    final double chartWidth = size.width - paddingLeft - paddingRight;
    final double chartHeight = size.height - paddingTop - paddingBottom;

    // Find min/max values
    double maxValue = 1.0;
    for (var val in data) {
      if (val > maxValue) maxValue = val;
    }

    // Gridlines & Labels
    final Paint gridPaint = Paint()
      ..color = const Color(0xFF1E293B).withAlpha(120)
      ..strokeWidth = 1.0;

    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // Draw horizontal grid lines
    const int gridLinesCount = 3;
    for (int i = 0; i <= gridLinesCount; i++) {
      final double ratio = i / gridLinesCount;
      final double y = paddingTop + chartHeight * (1 - ratio);
      canvas.drawLine(Offset(paddingLeft, y), Offset(size.width - paddingRight, y), gridPaint);

      // Draw value labels
      final double val = maxValue * ratio;
      textPainter.text = TextSpan(
        text: val.toStringAsFixed(0),
        style: const TextStyle(
          color: Color(0xFF475569),
          fontSize: 8.5,
          fontFamily: 'monospace',
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(paddingLeft - textPainter.width - 6, y - textPainter.height / 2),
      );
    }

    // Calculate chart points
    final double spacing = data.length > 1 ? chartWidth / (data.length - 1) : chartWidth;
    final List<Offset> points = [];
    for (int i = 0; i < data.length; i++) {
      final double x = paddingLeft + i * spacing;
      final double targetY = paddingTop + chartHeight * (1 - (data[i] / maxValue));
      // Animate from baseline
      final double baselineY = paddingTop + chartHeight;
      final double y = baselineY + (targetY - baselineY) * progress;
      points.add(Offset(x, y));
    }

    // Draw Area under the line (gradient)
    if (points.isNotEmpty) {
      final Path areaPath = Path()..moveTo(points.first.dx, paddingTop + chartHeight);
      for (var point in points) {
        areaPath.lineTo(point.dx, point.dy);
      }
      areaPath.lineTo(points.last.dx, paddingTop + chartHeight);
      areaPath.close();

      final Paint areaPaint = Paint()
        ..shader = LinearGradient(
          colors: [glowColor.withAlpha(50), glowColor.withAlpha(0)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTRB(paddingLeft, paddingTop, size.width - paddingRight, size.height - paddingBottom))
        ..style = PaintingStyle.fill;

      canvas.drawPath(areaPath, areaPaint);
    }

    // Draw Neon Glowing Stroke Line
    if (points.isNotEmpty) {
      final Path linePath = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        linePath.lineTo(points[i].dx, points[i].dy);
      }

      // Outer glow filter
      final Paint glowPaint = Paint()
        ..color = glowColor.withAlpha(120)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);

      canvas.drawPath(linePath, glowPaint);

      // Core crisp line
      final Paint strokePaint = Paint()
        ..color = glowColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;

      canvas.drawPath(linePath, strokePaint);
    }

    // Draw Dot points on top
    final Paint dotCorePaint = Paint()..color = Colors.white;
    final Paint dotOuterPaint = Paint()
      ..color = glowColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (int i = 0; i < points.length; i++) {
      canvas.drawCircle(points[i], 3.5, dotOuterPaint);
      canvas.drawCircle(points[i], 1.5, dotCorePaint);

      // Draw bottom X labels
      if (i < labels.length) {
        textPainter.text = TextSpan(
          text: labels[i].toUpperCase(),
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 8.0,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
          ),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(points[i].dx - textPainter.width / 2, size.height - paddingBottom + 8),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_NeonLinePainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.labels != labels ||
        oldDelegate.progress != progress ||
        oldDelegate.glowColor != glowColor;
  }
}
