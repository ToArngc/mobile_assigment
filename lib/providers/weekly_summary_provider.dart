import 'package:flutter/foundation.dart';
import '../models/weekly_ride_summary.dart';
import '../services/mute_service.dart';
import '../services/notification_service.dart';
import '../services/weekly_summary_repository.dart';

enum LoadStatus { initial, loading, loaded, error }

/// Backs the Weekly Summary screen.
///
/// No aggregation happens here. get-weekly-rides returns ride_count,
/// on_time_percentage and avg_delay_minutes already computed in SQL, so
/// this provider only surfaces them — that keeps the on-time rule in one
/// place instead of three.
class WeeklySummaryProvider extends ChangeNotifier {
  final WeeklySummaryRepository _repository;
  final String userId;

  WeeklySummaryProvider({
    required WeeklySummaryRepository repository,
    required this.userId,
  }) : _repository = repository;

  LoadStatus status = LoadStatus.initial;
  String? errorMessage;
  WeeklyRideSummary summary = WeeklyRideSummary.empty();

  /// The summary notification is a weekly digest, not a per-refresh
  /// alert — pull-to-refresh must not re-fire it.
  bool _notified = false;

  int get tripCount => summary.rideCount;

  double? get onTimePercent => summary.onTimePercentage;

  double? get averageDelayMinutes => summary.averageDelayMinutes;

  /// False when rides exist but none could be matched to a train_status
  /// reading — "not enough data yet", which the UI must show as distinct
  /// from 0%.
  bool get hasDelayData => summary.hasDelayData;

  Future<void> loadSummary() async {
    status = LoadStatus.loading;
    errorMessage = null;
    notifyListeners();

    try {
      summary = await _repository.getWeeklySummary(userId);
      status = LoadStatus.loaded;
      await _maybeNotify();
    } catch (e) {
      errorMessage = e.toString();
      status = LoadStatus.error;
    }
    notifyListeners();
  }

  Future<void> _maybeNotify() async {
    if (_notified || summary.rideCount == 0) return;
    try {
      // Quick Mute suppresses every local reminder (design doc §9).
      if (await MuteService.isMutedNow(userId)) return;
      await NotificationService.showWeeklySummary(
        rideCount: summary.rideCount,
        onTimePercentage: summary.onTimePercentage,
        averageDelayMinutes: summary.averageDelayMinutes,
      );
      _notified = true;
    } catch (_) {
      // A summary notification failing must never take down the screen
      // the user actually opened.
    }
  }
}
