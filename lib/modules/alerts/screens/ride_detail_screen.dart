import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../core/malaysia_time.dart';
import '../../../core/theme.dart';
import '../../../models/ride_log.dart';

class RideDetailScreen extends StatelessWidget {
  const RideDetailScreen({required this.ride, super.key});

  final RideLog ride;

  @override
  Widget build(BuildContext context) {
    final autoDetected = ride.hasFullTripDetail;
    final detectedAt = MalaysiaTime.fromUtc(ride.detectedAt);
    final detectedLabel =
        '${detectedAt.day.toString().padLeft(2, '0')} '
        '${_month(detectedAt.month)} ${detectedAt.year}, '
        '${detectedAt.hour.toString().padLeft(2, '0')}:'
        '${detectedAt.minute.toString().padLeft(2, '0')} MYT';

    return Scaffold(
      appBar: AppBar(title: const Text('Ride details')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  _DetailRow(
                    icon: Icons.trip_origin,
                    label: 'Origin station',
                    value: _available(ride.stationName),
                  ),
                  const Divider(height: 28),
                  _DetailRow(
                    icon: Icons.location_on_outlined,
                    label: 'Destination station',
                    value: _available(ride.destinationStationName),
                  ),
                  const Divider(height: 28),
                  _DetailRow(
                    icon: Icons.schedule,
                    label: 'Detected',
                    value: detectedLabel,
                  ),
                  const Divider(height: 28),
                  _DetailRow(
                    icon: Icons.timer_outlined,
                    label: 'Train delay',
                    value: ride.delayMinutes == null
                        ? 'Unavailable'
                        : '${ride.delayMinutes} minutes',
                  ),
                  const Divider(height: 28),
                  _DetailRow(
                    icon: Icons.timer_outlined,
                    label: 'Duration',
                    value: ride.durationMinutes == null
                        ? 'Unavailable'
                        : '${ride.durationMinutes} minutes',
                  ),
                  const Divider(height: 28),
                  _DetailRow(
                    icon: Icons.route_outlined,
                    label: 'Line',
                    value: _available(ride.stationLine),
                  ),
                  const Divider(height: 28),
                  _DetailRow(
                    icon: Icons.auto_awesome_outlined,
                    label: 'Source',
                    value: autoDetected ? 'Automatically detected' : 'Recorded',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            autoDetected
                ? 'Ride details are read-only and come from foreground station proximity detection.'
                : 'Ride details are read-only.',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  String _available(String? value) {
    final displayValue = value?.trim();
    return displayValue == null || displayValue.isEmpty
        ? 'Unavailable'
        : displayValue;
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: AppColors.accent),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    ],
  );
}
