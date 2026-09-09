import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../models/fault_report.dart';
import '../../../models/station.dart';
import '../../../services/reports_repository.dart';
import '../../../services/station_repository.dart';

class ReportDetailScreen extends StatelessWidget {
  const ReportDetailScreen({required this.report, super.key});

  final FaultReport report;

  @override
  Widget build(BuildContext context) {
    final open = report.status == FaultStatus.open;
    final category = ReportCategory.fromIssueType(report.issueType);

    return Scaffold(
      appBar: AppBar(title: const Text('Report details')),
      body: FutureBuilder<Station?>(
        future: StationRepository().getStationById(report.stationId),
        builder: (context, snapshot) {
          final station = snapshot.data;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        open ? Icons.error_outline : Icons.check_circle_outline,
                        color: open ? AppColors.warning : AppColors.success,
                        size: 30,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(category.label, style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 3),
                            Text(open ? 'Open report' : 'Resolved report'),
                          ],
                        ),
                      ),
                      _StatusChip(open: open),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _DetailCard(
                icon: Icons.location_on_outlined,
                title: 'Station',
                child: snapshot.connectionState == ConnectionState.waiting
                    ? const Text('Loading station…')
                    : Text(
                        station == null
                            ? 'Station details are unavailable.'
                            : '${station.name}\n${station.line}',
                      ),
              ),
              const SizedBox(height: 12),
              _DetailCard(
                icon: Icons.schedule_outlined,
                title: 'Submitted',
                child: Text(_formatDate(report.createdAt)),
              ),
              if (report.description != null && report.description!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                _DetailCard(
                  icon: Icons.notes_outlined,
                  title: 'Description',
                  child: Text(report.description!),
                ),
              ],
              if (report.photoUrl != null) ...[
                const SizedBox(height: 12),
                Text('Photo', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    report.photoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const _PhotoUnavailable(),
                  ),
                ),
              ],
              if (report.lat != null && report.lng != null) ...[
                const SizedBox(height: 12),
                _DetailCard(
                  icon: Icons.my_location_outlined,
                  title: 'Reported location',
                  child: Text(
                    '${report.lat!.toStringAsFixed(5)}, ${report.lng!.toStringAsFixed(5)}',
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final hour = local.hour == 0 ? 12 : (local.hour > 12 ? local.hour - 12 : local.hour);
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.day}/${local.month}/${local.year} · $hour:$minute $suffix';
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.icon, required this.title, required this.child});

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 5),
                    child,
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.open});

  final bool open;

  @override
  Widget build(BuildContext context) => Chip(
        label: Text(open ? 'Open' : 'Resolved'),
        labelStyle: TextStyle(color: open ? AppColors.warning : AppColors.success),
        backgroundColor:
            (open ? AppColors.warning : AppColors.success).withValues(alpha: 0.12),
        side: BorderSide.none,
      );
}

class _PhotoUnavailable extends StatelessWidget {
  const _PhotoUnavailable();

  @override
  Widget build(BuildContext context) => Container(
        height: 160,
        color: Colors.black12,
        alignment: Alignment.center,
        child: const Text('Photo unavailable'),
      );
}
