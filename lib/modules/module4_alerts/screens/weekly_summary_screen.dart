import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/weekly_summary_provider.dart';
import '../repositories/weekly_summary_repository.dart';
import '../../../core/auth_service.dart';

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
                style: TextStyle(color: Colors.grey),
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
            ],
          ),
        );
      },
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
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Text(value, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}