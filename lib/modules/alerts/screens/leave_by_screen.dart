import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/malaysia_time.dart';
import '../../../core/friendly_error.dart';
import '../../../core/theme.dart';
import '../../../models/saved_route.dart';
import '../../../providers/leave_by_provider.dart';
import '../../../services/leave_by_repository.dart';
import '../../../services/auth_service.dart';
import 'add_route_screen.dart';

class LeaveByScreen extends StatelessWidget {
  const LeaveByScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = AuthService.currentUserId;
    if (userId == null) {
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }

    return ChangeNotifierProvider(
      create: (_) =>
          LeaveByProvider(repository: LeaveByRepository(), userId: userId)
            ..loadAll(),
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Leave-By Planner')),
          body: const _LeaveByBody(),
          floatingActionButton: FloatingActionButton.extended(
            icon: const Icon(Icons.add),
            label: const Text('Add route'),
            onPressed: () async {
              final saved = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const AddRouteScreen()),
              );
              if (saved == true && context.mounted) {
                context.read<LeaveByProvider>().loadAll();
              }
            },
          ),
        ),
      ),
    );
  }
}

class _LeaveByBody extends StatelessWidget {
  const _LeaveByBody();

  @override
  Widget build(BuildContext context) {
    return Consumer<LeaveByProvider>(
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
                Text(
                  friendlyErrorMessage(
                    provider.errorMessage,
                    fallback: 'Your saved routes could not be loaded.',
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: provider.loadAll,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (provider.routes.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No saved routes yet. Add one to get a personalised '
                '"leave by" notification each morning.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: provider.loadAll,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            itemCount: provider.routes.length,
            itemBuilder: (context, index) {
              final route = provider.routes[index];
              final result = provider.results[route.id];
              return _LeaveByCard(
                route: route,
                result: result,
                failed: provider.failedRouteIds.contains(route.id),
                onDelete: () => _confirmRemoveRoute(
                  context,
                  provider,
                  route.id,
                  route.stationName ?? provider.stationName(route.originStationId),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _confirmRemoveRoute(
    BuildContext context,
    LeaveByProvider provider,
    String routeId,
    String routeName,
  ) async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove route?'),
        content: Text('Remove the leave-by reminder for $routeName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (shouldRemove == true && context.mounted) {
      await provider.removeRoute(routeId);
    }
  }
}

class _LeaveByCard extends StatelessWidget {
  const _LeaveByCard({
    required this.route,
    required this.result,
    required this.failed,
    required this.onDelete,
  });

  final SavedRoute route;
  final LeaveByResult? result;
  final bool failed;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final leaveBy = result == null ? null : MalaysiaTime.fromUtc(result!.leaveByTime);
    final departure = result == null
        ? null
        : MalaysiaTime.fromUtc(result!.nextScheduledDeparture);
    final time = leaveBy == null
        ? null
        : '${leaveBy.hour.toString().padLeft(2, '0')}:${leaveBy.minute.toString().padLeft(2, '0')}';
    final departureTime = departure == null
        ? null
        : '${departure.hour.toString().padLeft(2, '0')}:${departure.minute.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    route.stationName ?? 'Selected station',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Remove route',
                  onPressed: onDelete,
                ),
              ],
            ),
            Text(
              'From your current location · ${route.walkingMinutes} min walk',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const Divider(height: 24),
            if (result == null)
              Text(
                failed
                    ? friendlyErrorMessage(
                        null,
                        fallback: 'Leave-by time could not be calculated. '
                            'Check your connection and pull to refresh.',
                      )
                    : 'No upcoming scheduled train found today.',
              )
            else ...[
              _InfoRow(label: 'Next scheduled train', value: departureTime!),
              _InfoRow(
                label: 'Average delay',
                value: result!.hasEnoughData
                    ? '${result!.avgDelayMinutes.round()} min'
                    : 'Not enough data yet',
              ),
              const SizedBox(height: 12),
              Text(
                'Leave by $time',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 3),
              Text(
                '$departureTime train · ${route.walkingMinutes} min walk'
                '${result!.hasEnoughData ? ' · ${result!.sampleSize} delay records' : ''}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: const TextStyle(color: AppColors.textSecondary)),
            ),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      );
}
