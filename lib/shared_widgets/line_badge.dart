import 'package:flutter/material.dart';






class LineBadge extends StatelessWidget {
  final String line;

  const LineBadge(this.line, {super.key});

  static const Map<String, Color> _lineColors = {
    'Seremban Line': Color(0xFF4CAF6D),
    'Port Klang Line': Color(0xFF3B82C4),
    'ETS Intercity': Color(0xFFE07A3F),
  };

  @override
  Widget build(BuildContext context) {
    final color = _lineColors[line] ?? Colors.grey.shade600;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 5),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Text(
            line,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}