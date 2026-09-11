import 'dart:async';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';

import '../../../core/constants.dart';
import '../../../core/friendly_error.dart';
import '../../../core/theme.dart';
import '../../../models/station.dart';
import '../../../providers/reliability_provider.dart';
import '../../../services/auth_service.dart';
import '../../../services/location_service.dart';
import '../../../services/reliability_repository.dart';
import '../../../services/station_repository.dart';
import '../../../shared_widgets/app_empty_state.dart';
import '../../../shared_widgets/app_error_state.dart';
import '../../../shared_widgets/profile_action.dart';
import '../../../shared_widgets/section_label.dart';
import '../widgets/ontime_summary_card.dart';
import '../widgets/train_delay_list_tile.dart';
import '../widgets/trend_chart_widget.dart';
import 'route_suggestion_screen.dart';

class ReliabilityDashboardScreen extends StatelessWidget {
  const ReliabilityDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = AuthService.currentUserId;
    if (userId == null) {
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }

    return ChangeNotifierProvider(
      create: (_) => ReliabilityProvider(
        repository: ReliabilityRepository(),
        userId: userId,
      )..loadDashboard(const ReliabilityFilter()),
      child: const _ReliabilityDashboardScaffold(),
    );
  }
}

class _ReliabilityDashboardScaffold extends StatefulWidget {
  const _ReliabilityDashboardScaffold();

  @override
  State<_ReliabilityDashboardScaffold> createState() =>
      _ReliabilityDashboardScaffoldState();
}

class _ReliabilityDashboardScaffoldState extends State<_ReliabilityDashboardScaffold> {
  final _stationRepository = StationRepository();
  late Future<List<Station>> _stationsFuture;
  List<Station> _stations = const [];

  // Proactive connectivity signal — deliberately separate from LoadStatus in
  // ReliabilityProvider, which only reflects whether the last API call
  // succeeded. This banner reports device-level connectivity before a call
  // is even attempted, and leaves the existing friendly_error.dart /
  // AppErrorState failure-path messaging untouched.
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _offline = false;

  // Transient one-shot GPS resolution, modelled the same way
  // AddRouteScreen._gettingLocation is — not part of LoadStatus. Unlike
  // AddRouteScreen this doesn't drive any visible UI: the first load stays
  // unfiltered and immediate, and the resolved line (if any) is applied
  // afterward through the screen's normal loadDashboard() call.
  bool _resolvingLocation = false;

  @override
  void initState() {
    super.initState();
    _stationsFuture = _stationRepository.getAllStations();
    _stationsFuture.then(
      (stations) {
        if (mounted) setState(() => _stations = stations);
      },
      onError: (_) {},
    );

    _connectivity.checkConnectivity().then((results) {
      if (mounted) setState(() => _offline = _isOffline(results));
    });
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
      if (mounted) setState(() => _offline = _isOffline(results));
    });

    unawaited(_resolveNearestLine());
  }

  // Reuses LocationService.instance.getCurrentLocation() exactly as
  // AddRouteScreen (lib/modules/alerts/screens/add_route_screen.dart) does —
  // same singleton, same permission gate, same 8-second timeout, same
  // "fail silently and fall back" behaviour for every non-success outcome
  // (permission denied, denied forever, GPS unavailable, timeout).
  //
  // Known edge case: RideDetectionService already requests location
  // permission right after login (services/ride_detection_service.dart
  // start()), so in the common case LocationService.ensurePermission()
  // here sees an already-resolved status (granted or deniedForever) and
  // shows no dialog at all. A second OS permission prompt can only appear
  // if the login-time prompt was answered "deny" without "don't ask
  // again" — a re-askable `denied` status. That's standard Android
  // re-prompt behaviour, not a bug in this feature, and is left as-is
  // rather than worked around.
  Future<void> _resolveNearestLine() async {
    if (_resolvingLocation) return;
    _resolvingLocation = true;
    LocationData? location;
    try {
      location = await LocationService.instance
          .getCurrentLocation()
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // Falls through to the silent-fallback checks below, same as
      // AddRouteScreen._estimateWalkingTime.
    }
    _resolvingLocation = false;
    if (!mounted) return;
    if (location?.latitude == null || location?.longitude == null) return;

    final provider = context.read<ReliabilityProvider>();
    if (!provider.filter.isEmpty) return;

    final List<Station> stations;
    try {
      stations = await _stationsFuture;
    } catch (_) {
      return;
    }
    if (!mounted || stations.isEmpty) return;
    if (!provider.filter.isEmpty) return;

    final nearest = _nearestStation(location!.latitude!, location.longitude!, stations);
    if (nearest == null || nearest.lines.isEmpty) return;

    await provider.loadDashboard(ReliabilityFilter(lineId: nearest.lines.first));
  }

  Station? _nearestStation(double lat, double lng, List<Station> stations) {
    Station? best;
    var bestDistance = double.infinity;
    for (final station in stations) {
      final distance = _distanceMeters(lat, lng, station.lat, station.lng);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = station;
      }
    }
    return best;
  }

  double _distanceMeters(double lat1, double lng1, double lat2, double lng2) {
    const earthRadiusMeters = 6371000.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLng = _degToRad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earthRadiusMeters * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _degToRad(double deg) => deg * (math.pi / 180);

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  bool _isOffline(List<ConnectivityResult> results) =>
      results.isEmpty || results.every((result) => result == ConnectivityResult.none);

  String _stationLabel(String stationId) {
    for (final station in _stations) {
      if (station.id == stationId) return station.name;
    }
    return stationId;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ReliabilityProvider>(
      builder: (context, provider, _) => Scaffold(
        appBar: AppBar(
          title: const Text('Reliability'),
          actions: const [ProfileAction()],
        ),
        body: RefreshIndicator(
          onRefresh: () => provider.loadDashboard(provider.filter),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_offline) ...[
                _buildOfflineBanner(),
                const SizedBox(height: AppSpacing.md),
              ],
              _buildFilterBar(context, provider),
              const SizedBox(height: AppSpacing.md),
              if (provider.status == LoadStatus.loading ||
                  provider.status == LoadStatus.initial)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (provider.status == LoadStatus.error)
                ...[
                  AppErrorState(
                    message: friendlyErrorMessage(
                      provider.errorMessage,
                      fallback: 'Reliability data could not be loaded.',
                    ),
                    onRetry: () {
                      setState(() {
                        _stationsFuture = _stationRepository.getAllStations();
                      });
                      return provider.loadDashboard(provider.filter);
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const _RouteSuggestionEntry(),
                ]
              else ...[
                OnTimeSummaryCard(
                  onTimePercent: provider.currentOnTimePercent,
                  windowDays: provider.windowDaysUsed,
                ),
                const SizedBox(height: 12),
                if (provider.trendSeries.isEmpty)
                  const _EmptyTrendState()
                else
                  TrendChartWidget(stats: provider.trendSeries),
                const SizedBox(height: AppSpacing.md),
                const _RouteSuggestionEntry(),
                const SizedBox(height: AppSpacing.lg),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: SectionLabel('Recent arrivals'),
                ),
                const SizedBox(height: 8),
                if (provider.recentDelays.isEmpty)
                  const AppEmptyState(
                    icon: Icons.train_outlined,
                    title: 'No arrivals recorded yet for this filter.',
                    subtitle: null,
                    wrapped: false,
                  )
                else
                  ...provider.recentDelays.map(
                    (status) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: TrainDelayListTile(status: status),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: const Row(
        children: [
          Icon(Icons.wifi_off, color: AppColors.warning, size: 20),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              "You're offline. Reliability data may be outdated.",
              style: TextStyle(color: AppColors.warning),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context, ReliabilityProvider provider) {
    final filter = provider.filter;
    final chips = <Widget>[];

    if (filter.lineId != null) {
      chips.add(
        InputChip(
          avatar: const Icon(Icons.timeline, size: 18, color: AppColors.accent),
          label: Text('Line: ${filter.lineId}'),
          onDeleted: () => provider.loadDashboard(const ReliabilityFilter()),
          deleteButtonTooltipMessage: 'Show all lines',
          visualDensity: VisualDensity.compact,
        ),
      );
    }
    if (filter.stationId != null) {
      chips.add(
        InputChip(
          avatar: const Icon(Icons.place_outlined, size: 18, color: AppColors.accent),
          label: Text('Station: ${_stationLabel(filter.stationId!)}'),
          onDeleted: () => provider.loadDashboard(
            ReliabilityFilter(lineId: filter.lineId),
          ),
          deleteButtonTooltipMessage: 'Show all stations on this line',
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    chips.add(
      ActionChip(
        avatar: Icon(
          filter.isEmpty ? Icons.filter_alt_outlined : Icons.tune,
          size: 18,
          color: AppColors.accent,
        ),
        label: Text(filter.isEmpty ? 'Filter results' : 'Edit filters'),
        onPressed: () => _openFilters(context, provider),
        visualDensity: VisualDensity.compact,
      ),
    );

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: chips,
    );
  }

  Future<void> _openFilters(BuildContext context, ReliabilityProvider provider) async {
    final List<Station> stations;
    try {
      stations = await _stationsFuture;
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyErrorMessage(
              e,
              fallback: 'Stations could not be loaded. Pull down to retry.',
            ),
          ),
        ),
      );
      return;
    }
    if (!context.mounted) return;
    final selected = await showModalBottomSheet<ReliabilityFilter>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FilterSheet(stations: stations, filter: provider.filter),
    );
    if (selected != null && context.mounted) await provider.loadDashboard(selected);
  }
}

class _RouteSuggestionEntry extends StatelessWidget {
  const _RouteSuggestionEntry();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        leading: CircleAvatar(
          backgroundColor: AppColors.accent.withValues(alpha: 0.12),
          foregroundColor: AppColors.accent,
          child: const Icon(Icons.alt_route),
        ),
        title: Text(
          'Route suggestions',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: const Text('Find more reliable alternatives to your usual route'),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const RouteSuggestionScreen()),
        ),
      ),
    );
  }
}

class _EmptyTrendState extends StatelessWidget {
  const _EmptyTrendState();

  @override
  Widget build(BuildContext context) => const AppEmptyState(
        icon: Icons.show_chart,
        title: 'No arrival data yet — check back once the pipeline has been running a bit longer.',
        subtitle: null,
        wrapped: true,
      );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.stations, required this.filter});

  final List<Station> stations;
  final ReliabilityFilter filter;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String? _lineId;
  late String? _stationId;

  @override
  void initState() {
    super.initState();
    _lineId = widget.filter.lineId;
    _stationId = widget.filter.stationId;
  }

  List<String> get _lines {
    final lines = <String>{};
    for (final station in widget.stations) {
      lines.addAll(station.lines);
    }
    return lines.toList()..sort();
  }

  List<Station> get _lineStations => _lineId == null
      ? const []
      : widget.stations.where((station) => station.lines.contains(_lineId)).toList();

  @override
  Widget build(BuildContext context) {
    final lines = _lines;
    final lineValue = lines.contains(_lineId) ? _lineId : null;
    final lineStations = _lineStations;
    final stationIds = lineStations.map((station) => station.id).toSet();
    final stationValue = stationIds.contains(_stationId) ? _stationId : null;

    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.65,
        child: Column(
          children: [
            const SizedBox(height: 12),
            const Text('Filters', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  DropdownButtonFormField<String?>(
                    key: ValueKey(lineValue),
                    initialValue: lineValue,
                    decoration: const InputDecoration(labelText: 'Line', isDense: true),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All lines')),
                      ...lines.map(
                        (line) => DropdownMenuItem(value: line, child: Text(line)),
                      ),
                    ],
                    onChanged: (value) => setState(() {
                      _lineId = value;
                      if (value == null ||
                          !widget.stations
                              .where((station) => station.lines.contains(value))
                              .any((station) => station.id == _stationId)) {
                        _stationId = null;
                      }
                    }),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String?>(
                    key: ValueKey('$lineValue-$stationValue'),
                    initialValue: stationValue,
                    decoration: const InputDecoration(
                      labelText: 'Station',
                      hintText: 'Select a line first',
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All stations')),
                      ...lineStations.map(
                        (station) => DropdownMenuItem(
                          value: station.id,
                          child: Text(station.name),
                        ),
                      ),
                    ],
                    onChanged: _lineId == null
                        ? null
                        : (value) => setState(() => _stationId = value),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => setState(() {
                      _lineId = null;
                      _stationId = null;
                    }),
                    child: const Text('Reset'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(
                      ReliabilityFilter(lineId: _lineId, stationId: stationValue),
                    ),
                    child: const Text('Apply'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
