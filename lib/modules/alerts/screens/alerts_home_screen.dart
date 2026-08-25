import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/alerts_provider.dart';
import '../../../services/alerts_repository.dart';
import '../widgets/quick_mute_card.dart';
import '../../../services/auth_service.dart';
import 'select_station_screen.dart';
import 'weekly_summary_screen.dart';
import 'leave_by_screen.dart';

/// Entry screen for Module 4 — Personal Alerts.
/// Quick Mute lives inline at the top (see QuickMuteCard).
/// Saved stations (with their Alert Rules) list below.
/// Weekly Summary and Leave-By Planner entries are added later as
/// additional cards/sections once those features are built.
class AlertsHomeScreen extends StatelessWidget {
  const AlertsHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = AuthService.currentUserId;

    if (userId == null) {
      return const Scaffold(
        body: Center(child: Text('Not signed in')),
      );
    }

    return ChangeNotifierProvider(
      create: (_) => AlertsProvider(
        repository: AlertsRepository(),
        userId: userId,
      )..loadAll(),
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Alerts')),
          body: const _AlertsHomeBody(),
          floatingActionButton: FloatingActionButton.extended(
            icon: const Icon(Icons.add),
            label: const Text('Add station'),
            onPressed: () async {
              final saved = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const SelectStationScreen()),
              );
              // SelectStationScreen/AlertRuleEditScreen are pushed on the
              // root Navigator (outside this ChangeNotifierProvider's
              // scope), so they save directly via AlertsRepository and
              // just report back whether to refresh — they can't call
              // this provider's methods themselves.
              if (saved == true && context.mounted) {
                context.read<AlertsProvider>().loadAll();
              }
            },
          ),
        ),
      ),
    );
  }
}

class _AlertsHomeBody extends StatelessWidget {
  const _AlertsHomeBody();

  @override
  Widget build(BuildContext context) {
    return Consumer<AlertsProvider>(
      builder: (context, provider, _) {
        if (provider.status == LoadStatus.loading ||
            provider.status == LoadStatus.initial) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.status == LoadStatus.error) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Failed to load: ${provider.errorMessage}'),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: provider.loadAll,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: provider.loadAll,
          child: ListView(
            children: [
              const QuickMuteCard(),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.bar_chart),
                  title: const Text('This week'),
                  subtitle: const Text('See your commute stats'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const WeeklySummaryScreen()),
                    );
                  },
                ),
              ),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.directions_walk),
                  title: const Text('Leave-By Planner'),
                  subtitle: const Text('Get a personalised departure reminder'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LeaveByScreen()),
                    );
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Saved stations',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              if (provider.savedStations.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  child: Text(
                    'No saved stations yet. Add one from a station\'s page '
                        'to get delay alerts for your commute.',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              else
                ...provider.savedStations.map(
                      (station) => ListTile(
                    leading: const Icon(Icons.notifications_none),
                    title: Text('Station ${station.stationId}'),
                    subtitle: Text(
                      station.alertDelayThreshold != null
                          ? 'Alert if delay > ${station.alertDelayThreshold} min'
                          : 'No threshold set',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => provider.removeAlertRule(station.id),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}