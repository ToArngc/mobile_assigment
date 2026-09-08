import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/reliability_provider.dart';
import '../../../services/reliability_repository.dart';
import '../../../services/auth_service.dart';
import '../widgets/route_suggestion_card.dart';



class RouteSuggestionScreen extends StatelessWidget {
  const RouteSuggestionScreen({super.key});

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
      )..loadRouteSuggestions(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Route Suggestions')),
        body: const _RouteSuggestionBody(),
      ),
    );
  }
}

class _RouteSuggestionBody extends StatelessWidget {
  const _RouteSuggestionBody();

  @override
  Widget build(BuildContext context) {
    return Consumer<ReliabilityProvider>(
      builder: (context, provider, _) {
        if (provider.routeStatus == LoadStatus.loading ||
            provider.routeStatus == LoadStatus.initial) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.routeStatus == LoadStatus.error) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Failed to load: ${provider.routeErrorMessage}'),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: provider.loadRouteSuggestions,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (provider.routeSuggestions.isEmpty) {
          return RefreshIndicator(
            onRefresh: provider.loadRouteSuggestions,
            child: ListView(
              children: const [
                Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No saved routes yet. Add one from Alerts → Leave-By '
                    'Planner to see its reliability here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: provider.loadRouteSuggestions,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            itemCount: provider.routeSuggestions.length,
            itemBuilder: (context, index) =>
                RouteSuggestionCard(suggestion: provider.routeSuggestions[index]),
          ),
        );
      },
    );
  }
}
