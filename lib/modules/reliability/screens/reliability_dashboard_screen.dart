import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/reliability_provider.dart';
import '../../../services/reliability_repository.dart';
import '../../../services/station_repository.dart';
import '../../../services/auth_service.dart';
import '../../../models/station.dart';
import '../widgets/ontime_summary_card.dart';
import '../widgets/trend_chart_widget.dart';
import '../widgets/train_delay_list_tile.dart';
import 'route_suggestion_screen.dart';



class ReliabilityDashboardScreen extends StatelessWidget {
  const ReliabilityDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = AuthService.currentUserId;

    if (userId == null) {
      return const Scaffold(
        body: Center(child: Text('Not signed in')),
      );
    }

    return ChangeNotifierProvider(
      create: (_) => ReliabilityProvider(
        repository: ReliabilityRepository(),
        userId: userId,
      )..loadDashboard(const ReliabilityFilter()),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Reliability'),
          actions: [
            IconButton(
              icon: const Icon(Icons.alt_route),
              tooltip: 'Route suggestions',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RouteSuggestionScreen()),
              ),
            ),
          ],
        ),
        body: const _DashboardBody(),
      ),
    );
  }
}

class _DashboardBody extends StatefulWidget {
  const _DashboardBody();

  @override
  State<_DashboardBody> createState() => _DashboardBodyState();
}

class _DashboardBodyState extends State<_DashboardBody> {
  final _stationRepository = StationRepository();
  late Future<List<Station>> _stationsFuture;

  @override
  void initState() {
    super.initState();
    _stationsFuture = _stationRepository.getAllStations();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ReliabilityProvider>(
      builder: (context, provider, _) {
        return RefreshIndicator(
          onRefresh: () => provider.loadDashboard(provider.filter),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              FutureBuilder<List<Station>>(
                future: _stationsFuture,
                builder: (context, snapshot) {
                  return _FilterRow(
                    stations: snapshot.data ?? const [],
                    filter: provider.filter,
                    onChanged: provider.loadDashboard,
                  );
                },
              ),
              const SizedBox(height: 16),
              if (provider.status == LoadStatus.loading || provider.status == LoadStatus.initial)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (provider.status == LoadStatus.error)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      Text('Failed to load: ${provider.errorMessage}'),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => provider.loadDashboard(provider.filter),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              else ...[
                OnTimeSummaryCard(
                  onTimePercent: provider.currentOnTimePercent,
                  windowDays: provider.trendWindowDays,
                ),
                const SizedBox(height: 12),
                if (provider.trendSeries.isEmpty)
                  const _EmptyTrendState()
                else
                  TrendChartWidget(stats: provider.trendSeries),
                const SizedBox(height: 20),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text('Recent arrivals', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                ),
                const SizedBox(height: 8),
                if (provider.recentDelays.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No arrivals recorded yet for this filter.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                else
                  ...provider.recentDelays.map((status) => TrainDelayListTile(status: status)),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _EmptyTrendState extends StatelessWidget {
  const _EmptyTrendState();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No data yet for this line — check back once the pipeline has '
          'been running a bit longer.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      ),
    );
  }
}




class _FilterRow extends StatelessWidget {
  final List<Station> stations;
  final ReliabilityFilter filter;
  final ValueChanged<ReliabilityFilter> onChanged;

  const _FilterRow({
    required this.stations,
    required this.filter,
    required this.onChanged,
  });

  List<String> get _lines {
    final all = <String>{};
    for (final station in stations) {
      all.addAll(station.lines);
    }
    return all.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    final lines = _lines;
    final lineValue = lines.contains(filter.lineId) ? filter.lineId : null;
    final stationIds = stations.map((s) => s.id).toSet();
    final stationValue = stationIds.contains(filter.stationId) ? filter.stationId : null;
    String? stationName;
    for (final station in stations) {
      if (station.id == stationValue) {
        stationName = station.name;
        break;
      }
    }

    final linePicker = DropdownButtonFormField<String?>(
      initialValue: lineValue,
      decoration: const InputDecoration(labelText: 'Line', isDense: true),
      items: [
        const DropdownMenuItem(value: null, child: Text('All lines')),
        ...lines.map((line) => DropdownMenuItem(value: line, child: Text(line))),
      ],
      onChanged: (value) => onChanged(
        ReliabilityFilter(lineId: value, stationId: filter.stationId),
      ),
    );
    final stationPicker = DropdownButtonFormField<String?>(
      initialValue: stationValue,
      decoration: const InputDecoration(labelText: 'Station', isDense: true),
      items: [
        const DropdownMenuItem(value: null, child: Text('All stations')),
        ...stations.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))),
      ],
      onChanged: (value) => onChanged(
        ReliabilityFilter(lineId: filter.lineId, stationId: value),
      ),
    );

    final summary = '${lineValue ?? 'All lines'} · ${stationName ?? 'All stations'}';

    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        leading: const Icon(Icons.tune),
        title: const Text('Filters'),
        subtitle: Text(summary, maxLines: 1, overflow: TextOverflow.ellipsis),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 420) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    linePicker,
                    const SizedBox(height: 12),
                    stationPicker,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: linePicker),
                  const SizedBox(width: 12),
                  Expanded(child: stationPicker),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
