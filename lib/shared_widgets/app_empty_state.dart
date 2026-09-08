import 'package:flutter/material.dart';

import '../core/theme.dart';

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.wrapped,
    super.key,
  });

  final IconData? icon;
  final String title;
  final String? subtitle;
  final bool wrapped;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) Icon(icon, size: 40, color: AppColors.textSecondary),
        if (icon != null) const SizedBox(height: 8),
        Text(title, textAlign: TextAlign.center),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ],
    );
    final padded = Padding(padding: const EdgeInsets.all(24), child: content);
    return wrapped ? Card(margin: EdgeInsets.zero, child: padded) : padded;
  }
}
