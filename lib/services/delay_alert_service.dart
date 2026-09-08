import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/saved_station.dart';
import '../models/train_status.dart';
import 'alerts_repository.dart';
import 'auth_service.dart';
import 'mute_service.dart';
import 'notification_service.dart';
import 'reliability_repository.dart';

/// Checks personal saved-station rules while the app is running.
///
/// This is deliberately foreground-only. Running checks after the app is
/// terminated needs platform-specific background work and is outside the
/// current project architecture.
class DelayAlertService {
  DelayAlertService._();

  static final DelayAlertService instance = DelayAlertService._();
  static const _pollInterval = Duration(minutes: 1);
  static const _maxStatusAge = Duration(minutes: 15);

  final AlertsRepository _repository = AlertsRepository();
  final ReliabilityRepository _reliabilityRepository = ReliabilityRepository();
  final Set<String> _notifiedStatusKeys = <String>{};
  final ValueNotifier<DateTime?> lastCheckedAt = ValueNotifier<DateTime?>(null);
  Timer? _timer;
  bool _checking = false;

  bool get isRunning => _timer != null;

  Future<void> start() async {
    if (isRunning) return;
    await checkNow();
    _timer = Timer.periodic(_pollInterval, (_) => checkNow());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> checkNow() async {
    if (_checking) return;
    final userId = AuthService.currentUserId;
    if (userId == null) return;

    _checking = true;
    try {
      if (await MuteService.isMutedNow(userId)) return;

      final savedStations = await _repository.getSavedStations(userId);
      for (final rule in savedStations) {
        if (!_isRuleActiveNow(rule)) continue;
        // Module 2 owns the shared train-status query used by the
        // Reliability dashboard. Reuse it so both modules assess the same
        // latest live delay for a station.
        final recentStatuses = await _reliabilityRepository
            .fetchRecentTrainDelays(stationId: rule.stationId, limit: 1);
        final status = recentStatuses.isEmpty ? null : recentStatuses.first;
        if (status == null || !_isEligibleDelay(rule, status)) continue;

        final key = '${rule.id}:${status.id}:${status.recordedAt.toUtc().toIso8601String()}';
        if (!_notifiedStatusKeys.add(key)) continue;

        await NotificationService.showDelayAlert(
          id: key.hashCode & 0x7fffffff,
          stationName: rule.stationName ?? 'Saved station',
          line: status.line.isNotEmpty ? status.line : (rule.stationLine ?? ''),
          delayMinutes: status.delayMinutes!,
        );
      }
    } finally {
      lastCheckedAt.value = DateTime.now();
      _checking = false;
    }
  }

  bool _isRuleActiveNow(SavedStation rule) {
    if (!rule.enabled) return false;
    final now = DateTime.now();
    final activeDays = rule.activeDays;
    // Missing legacy values mean every day; an explicit empty selection
    // means the user has paused all days for this rule.
    if (activeDays != null &&
        !activeDays.contains(_weekdayLabel(now.weekday))) {
      return false;
    }
    return !_isInQuietHours(now, rule.quietHoursStart, rule.quietHoursEnd);
  }

  bool _isEligibleDelay(SavedStation rule, TrainStatus status) {
    final delay = status.delayMinutes;
    final threshold = rule.alertDelayThreshold;
    if (delay == null || threshold == null || delay <= threshold) return false;
    return DateTime.now().difference(status.recordedAt.toLocal()).abs() <=
        _maxStatusAge;
  }

  bool _isInQuietHours(DateTime now, String? start, String? end) {
    if (start == null || end == null) return false;
    final startMinutes = _minutesSinceMidnight(start);
    final endMinutes = _minutesSinceMidnight(end);
    if (startMinutes == null || endMinutes == null || startMinutes == endMinutes) {
      return false;
    }
    final nowMinutes = now.hour * 60 + now.minute;
    if (startMinutes < endMinutes) {
      return nowMinutes >= startMinutes && nowMinutes < endMinutes;
    }
    return nowMinutes >= startMinutes || nowMinutes < endMinutes;
  }

  int? _minutesSinceMidnight(String value) {
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return null;
    }
    return hour * 60 + minute;
  }

  String _weekdayLabel(int weekday) => const [
        'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
      ][weekday - 1];
}
