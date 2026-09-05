import 'package:flutter/foundation.dart';
import '../services/weekly_summary_repository.dart';
import '../models/ride_log.dart';

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
  List<RideLog> rides = [];

  int get tripCount => rides.length;

  double? get onTimePercent {
    final withDelay = rides.where((r) => r.delayMinutes != null).toList();
    if (withDelay.isEmpty) return null;
    final onTime = withDelay.where(
      (r) => r.delayMinutes! <= kOnTimeDelayThresholdMinutes,
    ).length;
    return onTime / withDelay.length * 100;
  }

  double? get averageDelayMinutes {
    final withDelay = rides.where((r) => r.delayMinutes != null).toList();
    if (withDelay.isEmpty) return null;
    final total = withDelay.fold<int>(0, (sum, r) => sum + r.delayMinutes!);
    return total / withDelay.length;
  }

  Future<void> loadSummary() async {
    status = LoadStatus.loading;
    errorMessage = null;
    notifyListeners();

    try {
      rides = await _repository.getRidesForLastWeek(userId);
      status = LoadStatus.loaded;
    } catch (e) {
      errorMessage = e.toString();
      status = LoadStatus.error;
    }
    notifyListeners();
  }
}
