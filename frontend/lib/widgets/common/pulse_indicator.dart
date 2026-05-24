import 'package:flutter/material.dart';

class PulseIndicator extends StatefulWidget {
  final String status;

  const PulseIndicator({
    super.key,
    required this.status,
  });

  @override
  State<PulseIndicator> createState() => _PulseIndicatorState();
}

class _PulseIndicatorState extends State<PulseIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;

    switch (widget.status) {
      case 'ONLINE':
        color = const Color(0xFF00FFCC);
        text = 'SECURE LINK';
        break;
      case 'OFFLINE':
        color = const Color(0xFFFF2A6D);
        text = 'OFFLINE';
        break;
      default:
        color = const Color(0xFFFFD200);
        text = 'SYNCING';
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (ctx, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withAlpha((255 * 0.06 * _animation.value).round()),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withAlpha((255 * 0.4 * _animation.value).round()),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withAlpha((255 * 0.8 * _animation.value).round()),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                text,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: color,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
