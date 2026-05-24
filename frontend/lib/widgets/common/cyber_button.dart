import 'package:flutter/material.dart';

class CyberButton extends StatefulWidget {
  final String text;
  final IconData? icon;
  final VoidCallback onPressed;
  final List<Color> gradientColors;
  final Color textColor;
  final double height;

  const CyberButton({
    super.key,
    required this.text,
    this.icon,
    required this.onPressed,
    this.gradientColors = const [Color(0xFF00FFCC), Color(0xFFBD00FF)],
    this.textColor = Colors.black,
    this.height = 54,
  });

  @override
  State<CyberButton> createState() => _CyberButtonState();
}

class _CyberButtonState extends State<CyberButton> with TickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  
  late AnimationController _gradientController;
  late Animation<double> _gradientAlignAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );

    // Dynamic gradient sweep animation
    _gradientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    
    _gradientAlignAnim = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _gradientController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _gradientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _animController.forward(),
      onTapUp: (_) => _animController.reverse(),
      onTapCancel: () => _animController.reverse(),
      onTap: widget.onPressed,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedBuilder(
          animation: _gradientAlignAnim,
          builder: (context, child) {
            return Container(
              height: widget.height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: (widget.gradientColors.first).withAlpha((255 * 0.35).round()),
                    blurRadius: 18,
                    spreadRadius: 1,
                    offset: const Offset(0, 4),
                  ),
                ],
                gradient: LinearGradient(
                  colors: widget.gradientColors,
                  begin: Alignment(_gradientAlignAnim.value, -1.0),
                  end: Alignment(-_gradientAlignAnim.value, 1.0),
                ),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, color: widget.textColor, size: 20),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    widget.text.toUpperCase(),
                    style: TextStyle(
                      color: widget.textColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 12.5,
                      letterSpacing: 1.8,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
