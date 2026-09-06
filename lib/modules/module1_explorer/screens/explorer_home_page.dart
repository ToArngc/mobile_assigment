import 'package:flutter/material.dart';

import '../../../models/station.dart';
import '../../../services/station_repository.dart';
import '../../../shared_widgets/line_badge.dart';
import 'live_map_page.dart';
import 'live_route_map.dart';
import 'station_detail_page.dart';

class ExplorerHomePage extends StatefulWidget {
  const ExplorerHomePage({super.key});

  @override
  State<ExplorerHomePage> createState() => _ExplorerHomePageState();
}

class _ExplorerHomePageState extends State<ExplorerHomePage> {
  final StationRepository _repository = StationRepository();
  final TextEditingController _searchController = TextEditingController();
  late Future<List<Station>> _stationsFuture;
  String _query = '';

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

  Future<void> _refresh() async {
    setState(() => _stationsFuture = _repository.getAllStations());
    await _stationsFuture;
  }

  List<Station> _filteredStations(List<Station> stations) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return stations;
    return stations.where((station) {
      return station.name.toLowerCase().contains(query) ||
          station.lines.any((line) => line.toLowerCase().contains(query));
    }).toList();
  }

  List<Station> _mapStations(List<Station> stations) {
    final portKlang = stations
        .where((station) => station.line.toLowerCase().contains('port klang'))
        .toList();
    return (portKlang.isNotEmpty ? portKlang : stations).take(8).toList();
  }

  void _openStation(Station station) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => StationDetailPage(station: station),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Station>>(
      future: _stationsFuture,
      builder: (context, snapshot) {
        final stations = snapshot.data ?? const <Station>[];
        final filtered = _filteredStations(stations);
        return RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Explore stations',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Nearby KTM stops',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xff5f6a6d),
                            ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _searchController,
                        onChanged: (value) => setState(() => _query = value),
                        decoration: InputDecoration(
                          hintText: 'Search stations or lines…',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear search',
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _query = '');
                                  },
                                ),
                          filled: true,
                          fillColor: const Color(0xffeef7f9),
                          border: _searchBorder,
                          enabledBorder: _searchBorder,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (snapshot.connectionState == ConnectionState.waiting)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snapshot.hasError)
                SliverFillRemaining(child: _LoadError(onRetry: _refresh))
              else ...[
                if (filtered.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(36),
                      child: Column(
                        children: [
                          Icon(Icons.train_outlined, size: 40),
                          SizedBox(height: 8),
                          Text('No stations found'),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.separated(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) => _StationCard(
                        station: filtered[index],
                        onTap: () => _openStation(filtered[index]),
                      ),
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 22, 16, 28),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LIVE TRAIN POSITIONS',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                                color: const Color(0xff5f6a6d),
                              ),
                        ),
                        const SizedBox(height: 8),
                        LiveRouteMap(
                          stations: _mapStations(stations),
                          compact: true,
                          onStationTap: _openStation,
                          onExpand: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => LiveMapPage(
                                stations: _mapStations(stations),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

final _searchBorder = OutlineInputBorder(
  borderRadius: BorderRadius.circular(18),
  borderSide: const BorderSide(color: Color(0xffd0e8ec)),
);

class _StationCard extends StatelessWidget {
  const _StationCard({required this.station, required this.onTap});
  final Station station;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xffe0eef0)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(children: [
            const Icon(Icons.location_on_outlined, color: Color(0xff006874)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    station.name,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: station.lines.map(LineBadge.new).toList(),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xff5f6a6d)),
          ]),
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Stations could not be loaded. Check your connection and try again.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ]),
        ),
      );
}
