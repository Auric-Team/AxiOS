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
        color: const Color(0x660F1420),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (borderGlowColors.first).withAlpha((255 * 0.08).round()),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: borderGlowColors.length > 1 ? Colors.transparent : borderGlowColors.first,
              width: 1.5,
            ),
            gradient: borderGlowColors.length > 1
                ? LinearGradient(
                    colors: borderGlowColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
          ),
          padding: padding ?? const EdgeInsets.all(20),
          child: child,
        ),
      ),
    );
  }
}
