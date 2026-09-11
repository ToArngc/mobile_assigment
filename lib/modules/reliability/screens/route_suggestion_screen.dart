import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../providers/reliability_provider.dart';
import '../../../services/reliability_repository.dart';
import '../../../services/auth_service.dart';
import '../../../core/friendly_error.dart';
import '../../../core/theme.dart';
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
        appBar: AppBar(
          title: const Text('Route Suggestions'),
          actions: [
            Consumer<ReliabilityProvider>(
              builder: (context, provider, _) => IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: 'Share suggestions',
                onPressed: provider.routeSuggestions.isEmpty
                    ? null
                    : () => _shareRouteSuggestions(provider.routeSuggestions),
              ),
            ),
          ],
        ),
        body: const _RouteSuggestionBody(),
      ),
    );
  }
}

String _statusLabel(RouteReliabilityStatus status) {
  switch (status) {
    case RouteReliabilityStatus.onTrack:
      return 'On Track';
    case RouteReliabilityStatus.delayed:
      return 'Delayed';
    case RouteReliabilityStatus.unreliable:
      return 'Unreliable';
    case RouteReliabilityStatus.notEnoughData:
      return 'Not enough data yet';
  }
}

void _shareRouteSuggestions(List<RouteSuggestion> suggestions) {
  final lines = suggestions.map((suggestion) {
    final percent = suggestion.weeklyOnTimePercent;
    final onTimeText = percent == null
        ? 'no on-time history yet'
        : '${percent.toStringAsFixed(0)}% on-time (last ${suggestion.daysOfData} day${suggestion.daysOfData == 1 ? '' : 's'})';
    return '${suggestion.originStationName} → ${suggestion.destinationStationName}: '
        '${_statusLabel(suggestion.status)} · $onTimeText';
  });

  SharePlus.instance.share(
    ShareParams(
      text: 'My OnJejak route reliability:\n\n${lines.join('\n')}',
      subject: 'OnJejak route reliability',
    ),
  );
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
                Text(
                  friendlyErrorMessage(
                    provider.routeErrorMessage,
                    fallback: 'Route suggestions could not be loaded.',
                  ),
                ),
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
                    style: TextStyle(color: AppColors.textSecondary),
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
