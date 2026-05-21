import 'package:flutter/material.dart';

class CyberTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hintText;
  final IconData? prefixIcon;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final Color focusColor;
  final bool enabled;

  const CyberTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hintText,
    this.prefixIcon,
    this.obscureText = false,
    this.onChanged,
    this.focusColor = const Color(0xFF00FFCC),
    this.enabled = true,
  });

  @override
  State<CyberTextField> createState() => _CyberTextFieldState();
}

class _CyberTextFieldState extends State<CyberTextField> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isWidgetEnabled = widget.enabled;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: isWidgetEnabled ? const Color(0xFF07090E) : const Color(0xFF030508),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isFocused && isWidgetEnabled ? widget.focusColor : const Color(0xFF1E293B),
          width: 1.5,
        ),
        boxShadow: _isFocused && isWidgetEnabled
            ? [
                BoxShadow(
                  color: widget.focusColor.withAlpha((255 * 0.12).round()),
                  blurRadius: 8,
                  spreadRadius: 1,
                )
              ]
            : [],
      ),
      child: TextField(
        controller: widget.controller,
        obscureText: widget.obscureText,
        focusNode: _focusNode,
        onChanged: widget.onChanged,
        enabled: isWidgetEnabled,
        style: TextStyle(
          fontSize: 13.5,
          color: isWidgetEnabled ? Colors.white : const Color(0xFF475569),
          fontFamily: 'monospace',
        ),
        decoration: InputDecoration(
          labelText: widget.label.toUpperCase(),
          labelStyle: TextStyle(
            color: _isFocused && isWidgetEnabled ? widget.focusColor : const Color(0xFF64748B),
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
          hintText: widget.hintText,
          hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 13),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          border: InputBorder.none,
          prefixIcon: widget.prefixIcon != null
              ? Icon(
                  widget.prefixIcon,
                  color: _isFocused && isWidgetEnabled ? widget.focusColor : const Color(0xFF475569),
                  size: 20,
                )
              : null,
        ),
      ),
    );
  }
}
