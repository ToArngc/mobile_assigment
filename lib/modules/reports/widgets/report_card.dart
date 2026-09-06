import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../models/fault_report.dart';
import '../../../services/reports_repository.dart' show ReportCategory;


class ReportCard extends StatelessWidget {
  final FaultReport report;
  final String? stationName;
  final VoidCallback? onMarkResolved;

  const ReportCard({
    super.key,
    required this.report,
    this.stationName,
    this.onMarkResolved,
  });

  String get _title => ReportCategory.fromIssueType(report.issueType).label;

  String get _relativeTime {
    final diff = DateTime.now().difference(report.createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Future<void> _confirmResolve(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as resolved?'),
        content: Text('This marks "$_title" as fixed. Other riders will see it as resolved.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Mark resolved')),
        ],
      ),
    );
    if (confirmed == true) onMarkResolved?.call();
  }

  @override
  Widget build(BuildContext context) {
    final open = report.status == FaultStatus.open;
    final subtitleParts = [
      if (stationName != null) stationName!,
      if (report.description != null) report.description!,
      _relativeTime,
    ];


    final actionable = open && onMarkResolved != null;

    return Card(
      child: ListTile(
        leading: Icon(
          open ? Icons.error_outline : Icons.check_circle_outline,
          color: open ? Colors.red.shade400 : AppColors.accent,
        ),
        title: Text(_title),
        subtitle: Text(subtitleParts.join(' · ')),
        trailing: actionable
            ? ActionChip(
          label: const Text('Open'),
          labelStyle: TextStyle(fontSize: 12, color: Colors.red.shade700),
          backgroundColor: Colors.red.shade50,
          side: BorderSide.none,
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onPressed: () => _confirmResolve(context),
        )
            : Chip(
          label: Text(open ? 'Open' : 'Resolved'),
          labelStyle: TextStyle(
            fontSize: 12,
            color: open ? Colors.red.shade700 : AppColors.accent,
          ),
          backgroundColor: open ? Colors.red.shade50 : AppColors.accent.withValues(alpha: 0.12),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          side: BorderSide.none,
        ),
      ),
    );
  }
}