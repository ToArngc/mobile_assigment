import 'package:flutter/material.dart';
import '../../../services/station_repository.dart';
import '../../../models/station.dart';
import 'alert_rule_edit_screen.dart';



class SelectStationScreen extends StatefulWidget {
  const SelectStationScreen({super.key});

  @override
  State<SelectStationScreen> createState() => _SelectStationScreenState();
}

class _SelectStationScreenState extends State<SelectStationScreen> {
  final _repository = StationRepository();
  late Future<List<Station>> _stationsFuture;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _stationsFuture = _repository.getAllStations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        title: const Text('Choose a station'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
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
          if (snapshot.hasError) {
            return Center(child: Text('Failed to load stations: ${snapshot.error}'));
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
                onTap: () async {
                  final saved = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => AlertRuleEditScreen(
                        stationId: station.id,
                        stationName: station.name,
                      ),
                    ),
                  );



                  if (saved == true && context.mounted) {
                    Navigator.of(context).pop(true);
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}