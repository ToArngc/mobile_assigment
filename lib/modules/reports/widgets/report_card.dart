import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../models/fault_report.dart';
import '../../../services/reports_repository.dart' show ReportCategory;

/// List tile for a single fault report. Used on ReportsHomeScreen ("My
/// reports", spans multiple stations — pass [stationName]) and inline on
/// ReportIssueScreen ("Recent reports for this station" — omit it, since
/// every card there is already scoped to the one station shown).
class ReportCard extends StatelessWidget {
  final FaultReport report;
  final String? stationName;

  /// Supplied only where every card is known to belong to the signed-in
  /// rider (the "My reports" list). Left null on the station feed, so the
  /// resolve action never appears on someone else's report.
  final VoidCallback? onResolve;

  const ReportCard({
    super.key,
    required this.report,
    this.stationName,
    this.onResolve,
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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Chip(
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
            if (open && onResolve != null)
              IconButton(
                icon: const Icon(Icons.check_circle_outline),
                tooltip: 'Mark resolved',
                onPressed: onResolve,
              ),
          ],
        ),
      ),
    );
  }
}
