import 'package:flutter/material.dart';
import '../../../core/constants.dart';
import '../../../core/theme.dart';
import '../../../models/train_status.dart';




class TrainDelayListTile extends StatelessWidget {
  final TrainStatus status;

  const TrainDelayListTile({super.key, required this.status});

  String get _label => status.tripId ?? 'Train ${status.id.substring(0, 8)}';

  String get _timeLabel {
    final time = (status.actualTime ?? status.scheduledTime).toLocal();
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final delay = status.delayMinutes;
    final onTime = (delay ?? 0) <= onTimeThresholdMinutes;

    return Card(
      child: ListTile(
        leading: Icon(
          onTime ? Icons.check_circle_outline : Icons.error_outline,
          color: onTime ? AppColors.accent : Colors.red.shade400,
        ),
        title: Text(_label),
        subtitle: Text('${status.line} · $_timeLabel'),
        trailing: Chip(
          label: Text(delay == null ? 'No data' : '${delay > 0 ? '+' : ''}$delay min'),
          labelStyle: TextStyle(
            fontSize: 12,
            color: onTime ? AppColors.accent : Colors.red.shade700,
          ),
          backgroundColor: onTime
              ? AppColors.accent.withValues(alpha: 0.12)
              : Colors.red.shade50,
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          side: BorderSide.none,
        ),
      ),
    );
  }
}
