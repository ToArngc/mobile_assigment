import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants.dart';
import '../../../core/theme.dart';
import '../../../providers/weekly_summary_provider.dart';
import '../../../models/weekly_ride_summary.dart';
import '../../../services/weekly_summary_repository.dart';
import '../../../services/auth_service.dart';

class WeeklySummaryScreen extends StatelessWidget {
  const WeeklySummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = AuthService.currentUserId;
    if (userId == null) {
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }

    return ChangeNotifierProvider(
      create: (_) => WeeklySummaryProvider(
        repository: WeeklySummaryRepository(),
        userId: userId,
      )..loadSummary(),
      child: Scaffold(
        appBar: AppBar(title: const Text('This week')),
        body: const _WeeklySummaryBody(),
      ),
    );
  }
}

class _WeeklySummaryBody extends StatelessWidget {
  const _WeeklySummaryBody();

  @override
  Widget build(BuildContext context) {
    return Consumer<WeeklySummaryProvider>(
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
                  onPressed: provider.loadSummary,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (provider.tripCount == 0) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No commute records yet this week. Rides are logged when '
                    'the app is open near a saved station during commute hours.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: provider.loadSummary,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Trips',
                      value: '${provider.tripCount}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: 'On-time',
                      value: provider.onTimePercent != null
                          ? '${provider.onTimePercent!.round()}%'
                          : '—',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: 'Avg delay',
                      value: provider.averageDelayMinutes != null
                          ? '${provider.averageDelayMinutes!.round()} min'
                          : '—',
                    ),
                  ),
                ],
              ),
              if (!provider.hasDelayData) ...[
                const SizedBox(height: 12),
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.hourglass_empty),
                    title: Text('Not enough data yet'),
                    subtitle: Text(
                      'Your rides are recorded, but none could be matched to a '
                      'train arrival record yet. On-time and average delay will '
                      'appear once the arrival feed covers your travel times.',
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 28),
              Text(
                'Ride history',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              if (provider.summary.rides.isEmpty)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.train_outlined),
                    title: Text('Ride details are not available yet'),
                  ),
                )
              else
                Card(
                  child: Column(
                    children: [
                      for (final ride in provider.summary.rides)
                        _RideHistoryTile(ride: ride),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _RideHistoryTile extends StatelessWidget {
  final WeeklyRide ride;

  const _RideHistoryTile({required this.ride});

  @override
  Widget build(BuildContext context) {
    final delay = ride.delayMinutes;
    final isOnTime = delay != null && delay <= onTimeThresholdMinutes;
    final date = ride.detectedAt.toLocal();
    final time = TimeOfDay.fromDateTime(date).format(context);
    final dateLabel = '${date.day}/${date.month}/${date.year}';
    final delayLabel = delay == null
        ? 'Delay unavailable'
        : isOnTime
            ? 'On time · ${delay} min delay'
            : '${delay} min delay';

    return ListTile(
      leading: Icon(
        delay == null
            ? Icons.help_outline
            : isOnTime
                ? Icons.check_circle_outline
                : Icons.warning_amber_outlined,
        color: delay == null
            ? null
            : isOnTime
                ? AppColors.success
                : AppColors.warning,
      ),
      title: Text(ride.stationName ?? 'Station'),
      subtitle: Text('$dateLabel · $time'),
      trailing: Text(
        delayLabel,
        textAlign: TextAlign.end,
        style: TextStyle(
          color: delay == null
              ? AppColors.neutral
              : isOnTime
                  ? AppColors.success
                  : AppColors.warning,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Column(
          children: [
            Text(value, style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
