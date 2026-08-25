import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
      create: (_) => LeaveByProvider(
        repository: LeaveByRepository(),
        userId: userId,
      )..loadAll(),
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
                Text('Failed to load: ${provider.errorMessage}'),
                const SizedBox(height: 8),
                ElevatedButton(onPressed: provider.loadAll, child: const Text('Retry')),
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
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: provider.loadAll,
          child: ListView.builder(
            itemCount: provider.routes.length,
            itemBuilder: (context, index) {
              final route = provider.routes[index];
              final result = provider.results[route.id];

              String subtitle;
              if (result == null) {
                subtitle = 'No upcoming departure found today';
              } else if (!result.hasEnoughData) {
                subtitle = 'Data accumulating — not enough history yet to estimate delay';
              } else {
                final t = result.leaveByTime;
                final timeStr =
                    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                subtitle = 'Leave by $timeStr (${result.avgDelayMinutes.round()} min avg delay)';
              }

              return ListTile(
                leading: const Icon(Icons.directions_walk),
                title: Text('${route.walkingMinutes} min walk to station'),
                subtitle: Text(subtitle),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => provider.removeRoute(route.id),
                ),
              );
            },
          ),
        );
      },
    );
  }
}