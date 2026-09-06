import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../models/fault_report.dart';
import '../../../services/reports_repository.dart' show ReportCategory;


class ReportDetailScreen extends StatefulWidget {
  final FaultReport report;
  final String? stationName;
  final VoidCallback? onMarkResolved;

  const ReportDetailScreen({
    super.key,
    required this.report,
    this.stationName,
    this.onMarkResolved,
  });

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  // Local copy so the button/status update immediately without waiting
  // for the caller's list to rebuild and this screen to be popped.
  late FaultStatus _status = widget.report.status;
  bool _resolving = false;

  String get _title => ReportCategory.fromIssueType(widget.report.issueType).label;

  Future<void> _confirmResolve() async {
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
    if (confirmed != true) return;

    setState(() => _resolving = true);

    widget.onMarkResolved?.call();
    if (!mounted) return;
    setState(() {
      _status = FaultStatus.resolved;
      _resolving = false;
    });
  }

  String _formatDateTime(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} · $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final open = _status == FaultStatus.open;
    final showResolveButton = open && widget.onMarkResolved != null;

    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (report.photoUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                report.photoUrl!,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 220,
                  color: Colors.grey.shade200,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          Row(
            children: [
              Icon(
                open ? Icons.error_outline : Icons.check_circle_outline,
                color: open ? Colors.red.shade400 : AppColors.accent,
              ),
              const SizedBox(width: 8),
              Chip(
                label: Text(open ? 'Open' : 'Resolved'),
                backgroundColor: open ? Colors.red.shade50 : AppColors.accent.withValues(alpha: 0.12),
                labelStyle: TextStyle(color: open ? Colors.red.shade700 : AppColors.accent),
                side: BorderSide.none,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (widget.stationName != null) ...[
            Text('Station', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(widget.stationName!, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
          ],

          if (report.description != null && report.description!.isNotEmpty) ...[
            Text('Description', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(report.description!),
            const SizedBox(height: 20),
          ],

          Text('Reported', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(_formatDateTime(report.createdAt), style: const TextStyle(color: Colors.grey)),
        ],
      ),
      bottomNavigationBar: showResolveButton
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: _resolving ? null : _confirmResolve,
                  child: _resolving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Mark as resolved'),
                ),
              ),
            )
          : null,
    );
  }
}
