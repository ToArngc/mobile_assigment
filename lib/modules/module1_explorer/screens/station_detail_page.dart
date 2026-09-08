import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../models/station.dart';
import '../../../models/station_accessibility.dart';
import '../../../models/timetable_entry.dart';
import '../../../services/station_repository.dart';

class StationDetailPage extends StatelessWidget {
  const StationDetailPage({required this.station, super.key});

  final Station station;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(station.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(station.name, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: station.lines
                        .map((line) => Chip(
                              avatar: const Icon(Icons.route_outlined, size: 18),
                              label: Text(line),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  Text('Location: ${station.lat.toStringAsFixed(5)}, ${station.lng.toStringAsFixed(5)}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Accessibility', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          _AccessibilityCard(stationId: station.id),
          const SizedBox(height: 20),
          Text('Scheduled departures', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          _Timetable(stationId: station.id),
        ],
      ),
    );
  }
}

class _AccessibilityCard extends StatelessWidget {
  const _AccessibilityCard({required this.stationId});

  final String stationId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<StationAccessibility>>(
      future: StationRepository().getStationAccessibility(stationId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        // An error means we could not reach the view, which is not the
        // same as "nothing is broken" — say so rather than implying the
        // station is fine.
        if (snapshot.hasError) {
          return Card(
            child: ListTile(
              leading: Icon(Icons.cloud_off_outlined, color: Colors.orange.shade700),
              title: const Text('Accessibility status could not be loaded.'),
              subtitle: const Text('Pull down or reopen this page to retry.'),
            ),
          );
        }

        final issues = (snapshot.data ?? const <StationAccessibility>[])
            .where((issue) => issue.isOpen)
            .toList();

        if (issues.isEmpty) {
          return Card(
            child: ListTile(
              leading: Icon(Icons.check_circle_outline, color: AppColors.accent),
              title: const Text('No accessibility issues reported'),
              subtitle: const Text('Riders have not flagged anything here.'),
            ),
          );
        }

        return Card(
          child: Column(
            children: issues
                .map((issue) => ListTile(
                      leading: Icon(
                        Icons.report_problem_outlined,
                        color: Colors.red.shade400,
                      ),
                      title: Text(_issueLabel(issue.issueType)),
                      subtitle: Text('Reported ${issue.relativeAge}'),
                    ))
                .toList(),
          ),
        );
      },
    );
  }

  /// fault_reports.issue_type has no check constraint, so an unknown
  /// value is possible — fall back to a readable form of whatever the
  /// reporter sent instead of dropping the row.
  String _issueLabel(String issueType) {
    switch (issueType) {
      case 'lift_broken':
        return 'Lift out of service';
      case 'escalator_broken':
        return 'Escalator out of service';
      case 'overcrowding':
        return 'Overcrowding';
      case 'cleanliness':
        return 'Cleanliness';
      case 'safety_hazard':
        return 'Safety hazard';
      default:
        return issueType.replaceAll('_', ' ');
    }
  }
}

class _Timetable extends StatelessWidget {
  const _Timetable({required this.stationId});

  final String stationId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TimetableEntry>>(
      future: StationRepository().getTimetableForStation(stationId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return const Card(
            child: ListTile(
              leading: Icon(Icons.schedule_outlined),
              title: Text('Timetable is unavailable right now.'),
            ),
          );
        }
        final entries = snapshot.data ?? const <TimetableEntry>[];
        if (entries.isEmpty) {
          return const Card(child: ListTile(title: Text('No scheduled departures found.')));
        }
        return Card(
          child: Column(
            children: entries.take(8).map((entry) {
              return ListTile(
                leading: const Icon(Icons.departure_board_outlined),
                title: Text(entry.scheduledTime.substring(0, 5)),
                subtitle: Text('${entry.line} · ${entry.direction}'),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
