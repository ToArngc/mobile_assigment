import 'package:flutter/material.dart';
import '../../module1_explorer/repositories/station_repository.dart';
import '../../../core/models/station.dart';

/// Generic station picker — pops the selected Station back to the caller.
/// Used by AddRouteScreen for picking origin and destination separately.
class PickStationScreen extends StatefulWidget {
  final String title;

  const PickStationScreen({super.key, required this.title});

  @override
  State<PickStationScreen> createState() => _PickStationScreenState();
}

class _PickStationScreenState extends State<PickStationScreen> {
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
        title: Text(widget.title),
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