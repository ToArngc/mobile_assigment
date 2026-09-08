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
  bool _liveMapExpanded = false;

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




  String _mapLine(List<Station> stations) {
    final mapped = _mapStations(stations);
    if (mapped.isEmpty) return '';
    final lines = mapped.first.lines;
    return lines.isEmpty ? mapped.first.line : lines.first;
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
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  sliver: SliverToBoxAdapter(
                    child: _LivePositionsSection(
                      stations: _mapStations(stations),
                      line: _mapLine(stations),
                      expanded: _liveMapExpanded,
                      onToggle: () => setState(() => _liveMapExpanded = !_liveMapExpanded),
                      onStationTap: _openStation,
                      onOpenFullMap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => LiveMapPage(
                            stations: _mapStations(stations),
                            line: _mapLine(stations),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
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

class _LivePositionsSection extends StatelessWidget {
  const _LivePositionsSection({
    required this.stations,
    required this.line,
    required this.expanded,
    required this.onToggle,
    required this.onStationTap,
    required this.onOpenFullMap,
  });

  final List<Station> stations;
  final String line;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<Station> onStationTap;
  final VoidCallback onOpenFullMap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xffd5e6eb)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  const Icon(Icons.train_outlined, color: Color(0xff1267a9)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Live train positions',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        Text(
                          expanded ? 'Tap to hide the route map' : 'Tap to view the route map',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: LiveRouteMap(
                stations: stations,
                line: line,
                compact: true,
                onStationTap: onStationTap,
                onExpand: onOpenFullMap,
              ),
            ),
            crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

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
