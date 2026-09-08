import 'package:flutter/material.dart';

import '../../../models/station.dart';
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
    return FutureBuilder<Map<String, dynamic>?>(
      future: StationRepository().getStationAccessibility(stationId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(child: Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())));
        }
        if (snapshot.hasError) {
          return const Card(child: ListTile(leading: Icon(Icons.info_outline), title: Text('Accessibility information is unavailable right now.')));
        }
        final features = snapshot.data;
        if (features == null || features.isEmpty) {
          return const Card(child: ListTile(leading: Icon(Icons.info_outline), title: Text('Accessibility information is not available yet.')));
        }
        final enabled = features.entries
            .where((entry) => entry.key != 'station_id' && entry.value == true)
            .map((entry) => entry.key.replaceAll('_', ' '))
            .toList();
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: enabled.isEmpty
                ? const Text('No accessibility facilities have been confirmed.')
                : Wrap(spacing: 8, runSpacing: 8, children: enabled.map((feature) => Chip(label: Text(feature))).toList()),
          ),
        );
      },
    );
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
