import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants.dart';
import '../../../core/friendly_error.dart';
import '../../../core/malaysia_time.dart';
import '../../../core/theme.dart';
import '../../../models/ride_log.dart';
import '../../../models/saved_station.dart';
import '../../../providers/alerts_provider.dart';
import '../../../services/alerts_repository.dart';
import '../../../services/auth_service.dart';
import '../../../shared_widgets/app_empty_state.dart';
import '../../../shared_widgets/line_badge.dart';
import '../../../shared_widgets/profile_action.dart';
import '../../../shared_widgets/section_label.dart';
import '../widgets/quick_mute_card.dart';
import 'alert_rule_edit_screen.dart';
import 'leave_by_screen.dart';
import 'ride_detail_screen.dart';
import 'select_station_screen.dart';
import 'weekly_summary_screen.dart';

class AlertsHomeScreen extends StatelessWidget {
  const AlertsHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = AuthService.currentUserId;
    if (userId == null) {
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }

    return ChangeNotifierProvider(
      create: (_) =>
          AlertsProvider(repository: AlertsRepository(), userId: userId)
            ..loadAll(),
      child: const _AlertsHomeScreen(),
    );
  }
}

class _AlertsHomeScreen extends StatelessWidget {
  const _AlertsHomeScreen();

  @override
  Widget build(BuildContext context) => Consumer<AlertsProvider>(
    builder: (context, provider, _) => Scaffold(
      appBar: AppBar(
        title: const Text('My alerts'),
        actions: [
          PopupMenuButton<_HeaderAction>(
            icon: const Icon(Icons.tune),
            tooltip: 'Alert options',
            onSelected: (action) =>
                _handleAlertAction(context, provider, action),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _HeaderAction.mute,
                child: Text('Mute alerts'),
              ),
              PopupMenuItem(
                value: _HeaderAction.summary,
                child: Text('Weekly summary'),
              ),
              PopupMenuItem(
                value: _HeaderAction.leaveBy,
                child: Text('Leave-By planner'),
              ),
            ],
          ),
          const ProfileAction(),
        ],
      ),
      body: _AlertsHomeBody(provider: provider),
    ),
  );
}

class _AlertsHomeBody extends StatelessWidget {
  const _AlertsHomeBody({required this.provider});

  final AlertsProvider provider;

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
                Text(
                  friendlyErrorMessage(
                    provider.errorMessage,
                    fallback: 'Your alerts could not be loaded.',
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

    return SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: provider.loadAll,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.xl,
              ),
              children: [
                const Text(
                  'Manage station notifications',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                if (provider.lastAlertCheckedAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Last checked: ${_formatCheckedTime(provider.lastAlertCheckedAt!)}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 14),
                _AlertStatusCard(
                  provider: provider,
                  onOpenMute: () => _handleAlertAction(context, provider, _HeaderAction.mute),
                ),
                const SizedBox(height: AppSpacing.lg),
                const SectionLabel('Saved stations'),
                const SizedBox(height: 8),
                if (provider.savedStations.isEmpty)
                  const AppEmptyState(
                    icon: Icons.notifications_off_outlined,
                    title: 'No saved stations yet. Add one to receive delay alerts.',
                    subtitle: null,
                    wrapped: false,
                  )
                else
                  ...provider.savedStations.map(
                    (station) => _SavedStationCard(
                      station: station,
                      onToggle: (enabled) =>
                          provider.toggleStationEnabled(station.id, enabled),
                      onEdit: () => _editStation(context, provider, station),
                      onRemove: () => _confirmRemoveAlert(
                        context,
                        provider,
                        station.id,
                        station.stationName ?? 'this station',
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 58,
                  child: OutlinedButton.icon(
                    onPressed: () => _addStation(context, provider),
                    icon: const Icon(Icons.add),
                    label: const Text('Add station'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      side: BorderSide(
                        color: AppColors.accent.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                const SectionLabel('Ride history'),
                if (provider.recentRides.isEmpty)
                  const _EmptyRideHistory()
                else
                  ...provider.recentRides.map(_RideHistoryCard.new),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _addStation(
    BuildContext context,
    AlertsProvider provider,
  ) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const SelectStationScreen()),
    );
    if (saved == true && context.mounted) await provider.loadAll();
  }

  Future<void> _editStation(
    BuildContext context,
    AlertsProvider provider,
    SavedStation station,
  ) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AlertRuleEditScreen(
          stationId: station.stationId,
          stationName: station.stationName ?? 'Saved station',
          existing: station,
        ),
      ),
    );
    if (saved == true && context.mounted) await provider.loadAll();
  }

  Future<void> _confirmRemoveAlert(
    BuildContext context,
    AlertsProvider provider,
    String savedStationId,
    String stationName,
  ) async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove alert?'),
        content: Text('Remove the delay alert for $stationName?'),
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
      await provider.removeAlertRule(savedStationId);
    }
  }
}

void _handleAlertAction(
  BuildContext context,
  AlertsProvider provider,
  _HeaderAction action,
) {
  switch (action) {
    case _HeaderAction.mute:
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => ChangeNotifierProvider.value(
          value: provider,
          child: const SafeArea(child: QuickMuteCard()),
        ),
      );
    case _HeaderAction.summary:
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const WeeklySummaryScreen()));
    case _HeaderAction.leaveBy:
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const LeaveByScreen()));
  }
}

enum _HeaderAction { mute, summary, leaveBy }

class _SavedStationCard extends StatelessWidget {
  const _SavedStationCard({
    required this.station,
    required this.onToggle,
    required this.onEdit,
    required this.onRemove,
  });

  final SavedStation station;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final lines = (station.stationLine ?? '')
        .split(RegExp(r'\s*(?:,|/|\||&| and )\s*', caseSensitive: false))
        .where((line) => line.isNotEmpty)
        .toList();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onEdit,
        onLongPress: onRemove,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      station.stationName ?? 'Saved station',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (lines.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 5,
                        children: lines.map(LineBadge.new).toList(),
                      )
                    else
                      const Text(
                        'Line unavailable',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    if (station.alertDelayThreshold != null) ...[
                      const SizedBox(height: 9),
                      Text(
                        'Alert when delay exceeds ${station.alertDelayThreshold} min',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                children: [
                  Switch(value: station.enabled, onChanged: onToggle),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_horiz),
                    onSelected: (value) {
                      if (value == 'remove') onRemove();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'remove',
                        child: Text('Remove alert'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertStatusCard extends StatelessWidget {
  const _AlertStatusCard({required this.provider, required this.onOpenMute});

  final AlertsProvider provider;
  final VoidCallback onOpenMute;

  @override
  Widget build(BuildContext context) {
    final muted = provider.isMutedNow;
    final enabledCount = provider.savedStations.where((station) => station.enabled).length;
    final color = muted ? AppColors.warning : AppColors.success;
    return Card(
      color: AppColors.cardBackground,
      surfaceTintColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.14),
              child: Icon(
                muted
                    ? Icons.notifications_off_outlined
                    : Icons.notifications_active_outlined,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    muted ? 'Alerts are muted' : 'Alerts are active',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    muted
                        ? 'No delay notifications will be sent right now.'
                        : '$enabledCount saved station${enabledCount == 1 ? '' : 's'} are monitored.',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onOpenMute,
              child: Text(muted ? 'Manage' : 'Mute'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyRideHistory extends StatelessWidget {
  const _EmptyRideHistory();

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(top: 10),
    child: const Padding(
      padding: EdgeInsets.all(22),
      child: Column(
        children: [
          Icon(Icons.route_outlined, size: 32, color: AppColors.textSecondary),
          SizedBox(height: 8),
          Text('No rides logged yet'),
          SizedBox(height: 4),
          Text(
            'Your completed rides will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    ),
  );
}

class _RideHistoryCard extends StatelessWidget {
  const _RideHistoryCard(this.ride);
  final RideLog ride;

  @override
  Widget build(BuildContext context) {
    final route = ride.destinationStationName == null
        ? (ride.stationName ?? 'Origin unavailable')
        : '${ride.stationName ?? 'Origin unavailable'} → ${ride.destinationStationName}';
    final date = MalaysiaTime.fromUtc(ride.detectedAt);
    final dateLabel =
        '${date.day.toString().padLeft(2, '0')} ${_month(date.month)} ${date.year} · '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')} MYT';
    return Card(
      margin: const EdgeInsets.only(top: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => RideDetailScreen(ride: ride)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (ride.stationLine != null) LineBadge(ride.stationLine!),
                  const Spacer(),
                  if (ride.durationMinutes != null)
                    Text(
                      '${ride.durationMinutes} min',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                route,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  const Icon(
                    Icons.schedule,
                    size: 15,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    dateLabel,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _month(int month) => const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][month - 1];
}

String _formatCheckedTime(DateTime time) {
  final local = time.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $period';
}
