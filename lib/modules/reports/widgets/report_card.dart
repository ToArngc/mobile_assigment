import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../models/fault_report.dart';
import '../../../services/reports_repository.dart' show ReportCategory;
import '../screens/report_detail_screen.dart';


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

  @override
  Widget build(BuildContext context) {
    final open = report.status == FaultStatus.open;
    final subtitleParts = [
      if (stationName != null) stationName!,
      if (report.description != null) report.description!,
      _relativeTime,
    ];

    return Card(
      child: ListTile(
        leading: Icon(
          open ? Icons.error_outline : Icons.check_circle_outline,
          color: open ? Colors.red.shade400 : AppColors.accent,
        ),
        title: Text(_title),
        subtitle: Text(subtitleParts.join(' · ')),
        trailing: Chip(
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
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ReportDetailScreen(
              report: report,
              stationName: stationName,
              onMarkResolved: onMarkResolved,
            ),
          ),
        ),
      ),
    );
  }
}