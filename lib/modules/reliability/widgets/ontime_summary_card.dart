import 'package:flutter/material.dart';
import '../../../core/theme.dart';



class OnTimeSummaryCard extends StatelessWidget {
  final double? onTimePercent;
  final int windowDays;

  const OnTimeSummaryCard({
    super.key,
    required this.onTimePercent,
    required this.windowDays,
  });

  @override
  Widget build(BuildContext context) {
    final percent = onTimePercent;
    final isGood = percent != null && percent >= 80;
    final isWatch = percent != null && percent >= 60;
    final color = isGood
        ? AppColors.accent
        : isWatch
            ? Colors.orange.shade800
            : Colors.red.shade700;
    final label = percent == null
        ? 'Waiting for data'
        : isGood
            ? 'Service running well'
            : isWatch
                ? 'Minor delays'
                : 'Major delays';
    return Card(
      color: percent == null ? null : color.withValues(alpha: 0.07),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Current on-time performance',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(
                  label: Text(label),
                  labelStyle: TextStyle(color: color, fontSize: 12),
                  backgroundColor: color.withValues(alpha: 0.12),
                  side: BorderSide.none,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (percent == null)
              const Text('No data yet', style: TextStyle(color: AppColors.textSecondary))
            else ...[
              Text(
                '${percent.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (percent / 100).clamp(0, 1).toDouble(),
                  minHeight: 8,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.16),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Over the last $windowDays day${windowDays == 1 ? '' : 's'}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
