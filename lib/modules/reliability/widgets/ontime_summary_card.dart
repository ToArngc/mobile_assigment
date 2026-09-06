import 'package:flutter/material.dart';
import '../../../core/theme.dart';

/// KPI card showing the current on-time % for the selected filter, over
/// however many days of trend data are actually available.
class OnTimeSummaryCard extends StatelessWidget {
  final double? onTimePercent; // null = no data at all
  final int windowDays;

  const OnTimeSummaryCard({
    super.key,
    required this.onTimePercent,
    required this.windowDays,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current on-time %', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (onTimePercent == null)
              const Text('No data yet', style: TextStyle(color: AppColors.textSecondary))
            else ...[
              Text(
                '${onTimePercent!.toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
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
