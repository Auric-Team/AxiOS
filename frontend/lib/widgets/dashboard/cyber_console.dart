import 'package:flutter/material.dart';

class CyberConsole extends StatelessWidget {
  final List<String> logs;
  final double height;

  const CyberConsole({
    super.key,
    required this.logs,
    this.height = 180,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF030508),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
      ),
      padding: const EdgeInsets.all(16),
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        itemCount: logs.length,
        itemBuilder: (ctx, index) {
          final log = logs[index];
          Color textColor = const Color(0xFF8E9AAA);

          if (log.toUpperCase().contains('SUCCESS')) {
            textColor = const Color(0xFF00FFCC);
          } else if (log.toUpperCase().contains('ERROR') || log.toUpperCase().contains('FAIL')) {
            textColor = const Color(0xFFFF2A6D);
          } else if (log.toUpperCase().contains('WARNING') || log.toUpperCase().contains('WARN')) {
            textColor = const Color(0xFFFFD200);
          } else if (log.toUpperCase().contains('INIT') || log.toUpperCase().contains('BOOT') || log.toUpperCase().contains('LAUNCH')) {
            textColor = const Color(0xFFBD00FF);
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 6.0),
            child: Text(
              log,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10.5,
                color: textColor,
                height: 1.4,
              ),
            ),
          );
        },
      ),
    );
  }
}
