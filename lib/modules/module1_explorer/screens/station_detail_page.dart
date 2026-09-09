import 'package:flutter/material.dart';

import '../../../core/constants.dart';
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
          const SizedBox(height: AppSpacing.lg),
          Text('Scheduled departures', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          _Timetable(stationId: station.id),
        ],
      ),
    );
  }
}

class _AccessibilityCard extends StatefulWidget {
  const _AccessibilityCard({required this.stationId});

  final String stationId;

  @override
  State<_AccessibilityCard> createState() => _AccessibilityCardState();
}

class _AccessibilityCardState extends State<_AccessibilityCard> {
  final StationRepository _repository = StationRepository();
  late Future<List<StationAccessibility>> _accessibilityFuture;

  @override
  void initState() {
    super.initState();
    _accessibilityFuture = _repository.getStationAccessibility(
      widget.stationId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<StationAccessibility>>(
      future: _accessibilityFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }




        if (snapshot.hasError) {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.cloud_off_outlined, color: AppColors.warning),
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
              leading: const Icon(Icons.check_circle_outline, color: AppColors.success),
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
                        color: AppColors.danger,
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

class _Timetable extends StatefulWidget {
  const _Timetable({required this.stationId});

  final String stationId;

  @override
  State<_Timetable> createState() => _TimetableState();
}

class _TimetableState extends State<_Timetable> {
  final StationRepository _repository = StationRepository();
  late Future<List<TimetableEntry>> _timetableFuture;

  @override
  void initState() {
    super.initState();
    _timetableFuture = _repository.getTimetableForStation(widget.stationId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TimetableEntry>>(
      future: _timetableFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: CircularProgressIndicator(),
            ),
          );
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
          return const Card(
            child: ListTile(title: Text('No more departures scheduled today.')),
          );
        }
        return Card(
          child: Column(
            children: entries.map((entry) {
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
