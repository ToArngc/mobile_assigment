import 'package:flutter/foundation.dart';
import '../models/weekly_ride_summary.dart';
import '../services/mute_service.dart';
import '../services/notification_service.dart';
import '../services/weekly_summary_repository.dart';

enum LoadStatus { initial, loading, loaded, error }







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







  static final Set<String> _notifiedUserIds = <String>{};

  int get tripCount => summary.rideCount;

  double? get onTimePercent => summary.onTimePercentage;

  double? get averageDelayMinutes => summary.averageDelayMinutes;




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
    if (_notifiedUserIds.contains(userId) || summary.rideCount == 0) return;
    try {

      if (await MuteService.isMutedNow(userId)) return;
      await NotificationService.showWeeklySummary(
        rideCount: summary.rideCount,
        onTimePercentage: summary.onTimePercentage,
        averageDelayMinutes: summary.averageDelayMinutes,
      );
      _notifiedUserIds.add(userId);
    } catch (_) {


    }
  }
}
