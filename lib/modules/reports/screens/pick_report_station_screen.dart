import 'package:flutter/material.dart';
import '../../../services/station_repository.dart';
import '../../../models/station.dart';

/// Station picker for Module 3. Kept as its own copy rather than importing
/// PickStationScreen across module folders — same pattern as Module 4
/// having both PickStationScreen and SelectStationScreen instead of one
/// shared screen.
class PickReportStationScreen extends StatefulWidget {
  const PickReportStationScreen({super.key});

  @override
  State<PickReportStationScreen> createState() => _PickReportStationScreenState();
}

class _PickReportStationScreenState extends State<PickReportStationScreen> {
  final _repository = StationRepository();
  late Future<List<Station>> _stationsFuture;

  @override
  void initState() {
    super.initState();
    _stationsFuture = _repository.getAllStations();
  }

  void _search(String query) {
    setState(() {
      _stationsFuture = query.isEmpty
          ? _repository.getAllStations()
          : _repository.searchStations(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select station'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              onChanged: _search,
              decoration: const InputDecoration(
                hintText: 'Search stations...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
        ),
      ),
      body: FutureBuilder<List<Station>>(
        future: _stationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final stations = snapshot.data ?? [];
          if (stations.isEmpty) {
            return const Center(child: Text('No stations found'));
          }
          return ListView.builder(
            itemCount: stations.length,
            itemBuilder: (context, index) {
              final station = stations[index];
              return ListTile(
                leading: const Icon(Icons.train),
                title: Text(station.name),
                subtitle: Text(station.line),
                onTap: () => Navigator.of(context).pop(station),
              );
            },
          );
        },
      ),
    );
  }
}
