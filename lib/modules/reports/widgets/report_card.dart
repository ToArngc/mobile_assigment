import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../models/fault_report.dart';
import '../../../services/reports_repository.dart' show ReportCategory;





class ReportCard extends StatelessWidget {
  final FaultReport report;
  final String? stationName;

  final VoidCallback? onResolve;
  final VoidCallback? onTap;

  const ReportCard({
    super.key,
    required this.report,
    this.stationName,
    this.onResolve,
    this.onTap,
  });

  String get _title => ReportCategory.fromIssueType(report.issueType).label;

  IconData get _categoryIcon => switch (report.issueType) {
        'lift_broken' => Icons.elevator_outlined,
        'escalator_broken' => Icons.escalator_warning,
        'overcrowding' => Icons.groups_outlined,
        'cleanliness' => Icons.cleaning_services_outlined,
        'safety_hazard' => Icons.health_and_safety_outlined,
        _ => Icons.report_problem_outlined,
      };

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
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: (open ? AppColors.warning : AppColors.success).withValues(alpha: 0.12),
          child: Icon(
            _categoryIcon,
            color: open ? AppColors.warning : AppColors.success,
          ),
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
                color: open ? AppColors.warning : AppColors.success,
              ),
              backgroundColor: (open ? AppColors.warning : AppColors.success)
                  .withValues(alpha: 0.12),
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
            if (report.photoUrl != null)
              const Padding(
                padding: EdgeInsets.only(left: 2),
                child: Icon(Icons.photo_outlined, size: 19),
              ),
            if (onTap != null) const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
