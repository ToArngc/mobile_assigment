import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../services/reliability_repository.dart';

/// One saved route's card on the Route Suggestion screen — status badge
/// plus an alternate-line suggestion when the trigger logic surfaces one.
class RouteSuggestionCard extends StatelessWidget {
  final RouteSuggestion suggestion;

  const RouteSuggestionCard({super.key, required this.suggestion});

  (String, Color) _badge(RouteReliabilityStatus status) {
    switch (status) {
      case RouteReliabilityStatus.onTrack:
        return ('On Track', AppColors.accent);
      case RouteReliabilityStatus.delayed:
        return ('Delayed', Colors.red.shade700);
      case RouteReliabilityStatus.unreliable:
        return ('Unreliable', Colors.orange.shade800);
      case RouteReliabilityStatus.notEnoughData:
        return ('Not enough data yet', AppColors.textSecondary);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = suggestion.status;
    final (badgeLabel, badgeColor) = _badge(status);
    final showAlternate = status != RouteReliabilityStatus.onTrack &&
        status != RouteReliabilityStatus.notEnoughData &&
        suggestion.alternateLine != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${suggestion.originStationName} → ${suggestion.destinationStationName}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(
                  label: Text(badgeLabel),
                  labelStyle: TextStyle(fontSize: 12, color: badgeColor),
                  backgroundColor: badgeColor.withValues(alpha: 0.12),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  side: BorderSide.none,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              suggestion.weeklyOnTimePercent == null
                  ? '${suggestion.originLine} · no on-time history yet'
                  : '${suggestion.originLine} · ${suggestion.weeklyOnTimePercent!.toStringAsFixed(0)}% on-time '
                      '(last ${suggestion.daysOfData} day${suggestion.daysOfData == 1 ? '' : 's'})',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            if (showAlternate) ...[
              const SizedBox(height: 8),
              Text(
                'Consider ${suggestion.alternateLine} instead — '
                '${suggestion.alternateLineOnTimePercent!.toStringAsFixed(0)}% on-time',
                style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
