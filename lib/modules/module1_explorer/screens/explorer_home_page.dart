<<<<<<< Updated upstream
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
=======
import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../core/theme.dart';
import '../../../models/station.dart';
import '../../../services/station_repository.dart';
import '../../../shared_widgets/app_empty_state.dart';
import '../../../shared_widgets/app_error_state.dart';
import '../../../shared_widgets/line_badge.dart';
import 'live_map_page.dart';
import 'live_route_map.dart';
import 'station_detail_page.dart';

typedef ExplorerLiveMapBuilder =
    Widget Function({
      required List<Station> stations,
      required String line,
      required ValueChanged<Station> onStationTap,
      required VoidCallback onExpand,
    });

class ExplorerHomePage extends StatefulWidget {
  const ExplorerHomePage({super.key, this.loadStations, this.liveMapBuilder});

  final Future<List<Station>> Function()? loadStations;
  final ExplorerLiveMapBuilder? liveMapBuilder;

  @override
  State<ExplorerHomePage> createState() => _ExplorerHomePageState();
}

class _ExplorerHomePageState extends State<ExplorerHomePage> {
  final StationRepository _repository = StationRepository();
  final TextEditingController _searchController = TextEditingController();
>>>>>>> Stashed changes
  late Future<List<Station>> _stationsFuture;
  String _query = '';
  String? _selectedLine;
  bool _liveMapExpanded = false;
<<<<<<< Updated upstream

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
=======

  @override
  void initState() {
    super.initState();
    _stationsFuture = _loadStations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _stationsFuture = _loadStations());
    await _stationsFuture;
  }

  Future<List<Station>> _loadStations() async {
    final stations =
        await (widget.loadStations?.call() ?? _repository.getAllStations());
    final lines = _availableLines(stations);
    final nextLine = lines.contains(_selectedLine)
        ? _selectedLine
        : lines.isEmpty
        ? null
        : lines.first;
    if (mounted && nextLine != _selectedLine) {
      setState(() => _selectedLine = nextLine);
    }
    return stations;
  }

  List<String> _availableLines(List<Station> stations) =>
      <String>{for (final station in stations) ...station.lines}.toList()
        ..sort();

  List<Station> _filteredStations(List<Station> stations) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return stations;
    return stations.where((station) {
      return station.name.toLowerCase().contains(query) ||
          station.lines.any((line) => line.toLowerCase().contains(query));
    }).toList();
  }

  List<Station> _mapStations(List<Station> stations, String line) {
>>>>>>> Stashed changes
    final matching = stations
        .where((station) => station.lines.contains(line))
        .toList();
    return _orderRouteStations(matching);
  }

  List<Station> _orderRouteStations(List<Station> stations) {
    if (stations.length < 3) return stations;
<<<<<<< Updated upstream
    final remaining = List<Station>.from(stations);
    remaining.sort((a, b) => a.lng.compareTo(b.lng));
    final ordered = <Station>[remaining.removeAt(0)];
    while (remaining.isNotEmpty) {
      final current = ordered.last;
      remaining.sort((a, b) => _distanceSquared(current, a)
          .compareTo(_distanceSquared(current, b)));
=======
    final remaining = List<Station>.from(stations)
      ..sort((a, b) => a.lng.compareTo(b.lng));
    final ordered = <Station>[remaining.removeAt(0)];
    while (remaining.isNotEmpty) {
      final current = ordered.last;
      remaining.sort(
        (a, b) => _distanceSquared(
          current,
          a,
        ).compareTo(_distanceSquared(current, b)),
      );
>>>>>>> Stashed changes
      ordered.add(remaining.removeAt(0));
    }
    return ordered;
  }

  double _distanceSquared(Station a, Station b) {
    final latDelta = a.lat - b.lat;
    final lngDelta = a.lng - b.lng;
    return (latDelta * latDelta) + (lngDelta * lngDelta);
  }

<<<<<<< Updated upstream


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
=======
  void _openStation(Station station) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StationDetailPage(station: station),
      ),
    );
  }

  void _openLine(String line, List<Station> stations) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _LineStationsPage(line: line, stations: stations),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Explore stations'),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: TextField(
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
              fillColor: Theme.of(context).colorScheme.surface,
              border: _searchBorder,
              enabledBorder: _searchBorder,
            ),
          ),
        ),
      ),
    ),
    body: FutureBuilder<List<Station>>(
      future: _stationsFuture,
      builder: (context, snapshot) {
        final stations = snapshot.data ?? const <Station>[];
        final filtered = _filteredStations(stations);
        final lines = _availableLines(stations);
        final selectedLine = lines.contains(_selectedLine)
            ? _selectedLine!
            : lines.isEmpty
            ? ''
            : lines.first;
        final mapStations = _mapStations(stations, selectedLine);

        return RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (snapshot.connectionState == ConnectionState.waiting)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snapshot.hasError)
                SliverFillRemaining(
                  child: AppErrorState(
                    message:
                        'Stations could not be loaded. Check your connection and try again.',
                    onRetry: _refresh,
                  ),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  sliver: SliverToBoxAdapter(
                    child: _LivePositionsSection(
                      stations: mapStations,
                      availableLines: lines,
                      line: selectedLine,
                      expanded: _liveMapExpanded,
                      onLineChanged: (line) =>
                          setState(() => _selectedLine = line),
                      onToggle: () =>
                          setState(() => _liveMapExpanded = !_liveMapExpanded),
                      onStationTap: _openStation,
                      liveMapBuilder: widget.liveMapBuilder,
                      onOpenFullMap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => LiveMapPage(
                            stations: mapStations,
                            line: selectedLine,
>>>>>>> Stashed changes
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (filtered.isEmpty)
<<<<<<< Updated upstream
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

=======
                  const SliverToBoxAdapter(
                    child: AppEmptyState(
                      icon: Icons.train_outlined,
                      title: 'No stations found',
                      subtitle: null,
                      wrapped: false,
                    ),
                  )
                else if (_query.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.separated(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) => _StationCard(
                        station: filtered[index],
                        onTap: () => _openStation(filtered[index]),
                      ),
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.sm),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.separated(
                      itemCount: lines.length,
                      itemBuilder: (context, index) => _LineCard(
                        line: lines[index],
                        stationCount: stations
                            .where(
                              (station) => station.lines.contains(lines[index]),
                            )
                            .length,
                        onTap: () => _openLine(lines[index], stations),
                      ),
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.sm),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    ),
  );
}

>>>>>>> Stashed changes
final _searchBorder = OutlineInputBorder(
  borderRadius: BorderRadius.circular(18),
  borderSide: const BorderSide(color: Color(0xffd0e8ec)),
);

class _LivePositionsSection extends StatelessWidget {
  const _LivePositionsSection({
    required this.stations,
    required this.availableLines,
    required this.line,
    required this.expanded,
    required this.onLineChanged,
    required this.onToggle,
    required this.onStationTap,
    required this.onOpenFullMap,
    this.liveMapBuilder,
  });

  final List<Station> stations;
  final List<String> availableLines;
  final String line;
  final bool expanded;
  final ValueChanged<String> onLineChanged;
  final VoidCallback onToggle;
  final ValueChanged<Station> onStationTap;
  final VoidCallback onOpenFullMap;
  final ExplorerLiveMapBuilder? liveMapBuilder;

  @override
<<<<<<< Updated upstream
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
=======
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 13,
            ),
            child: Row(
              children: [
                const Icon(Icons.train_outlined, color: AppColors.accent),
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
                        expanded
                            ? 'Tap to hide the route map'
                            : 'Tap to view the route map',
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
            child: Column(
              children: [
                if (availableLines.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    key: ValueKey('map-line-selector-$line'),
                    initialValue: line,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Map line',
                      prefixIcon: Icon(Icons.route_outlined),
                    ),
                    items: [
                      for (final availableLine in availableLines)
                        DropdownMenuItem(
                          value: availableLine,
                          child: Text(availableLine),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) onLineChanged(value);
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                if (liveMapBuilder == null)
                  LiveRouteMap(
                    stations: stations,
                    line: line,
                    compact: true,
                    onStationTap: onStationTap,
                    onExpand: onOpenFullMap,
                  )
                else
                  liveMapBuilder!(
                    stations: stations,
                    line: line,
                    onStationTap: onStationTap,
                    onExpand: onOpenFullMap,
                  ),
              ],
            ),
          ),
          crossFadeState: expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    ),
  );
}

class _LineCard extends StatelessWidget {
  const _LineCard({
    required this.line,
    required this.stationCount,
    required this.onTap,
  });

  final String line;
  final int stationCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: ListTile(
      leading: const Icon(Icons.train_outlined, color: AppColors.accent),
      title: Text(line),
      subtitle: Text('$stationCount station${stationCount == 1 ? '' : 's'}'),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      onTap: onTap,
    ),
  );
}

class _StationCard extends StatelessWidget {
  const _StationCard({required this.station, required this.onTap});

  final Station station;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(
          children: [
            const Icon(Icons.train_outlined, color: AppColors.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    station.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
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
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    ),
  );
}

class _LineStationsPage extends StatelessWidget {
  const _LineStationsPage({required this.line, required this.stations});

  final String line;
  final List<Station> stations;

  @override
  Widget build(BuildContext context) {
    final lineStations = stations
        .where((station) => station.lines.contains(line))
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(line)),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: lineStations.length,
        itemBuilder: (context, index) => _StationCard(
          station: lineStations[index],
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => StationDetailPage(station: lineStations[index]),
>>>>>>> Stashed changes
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
