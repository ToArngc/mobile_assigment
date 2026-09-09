import 'package:flutter/foundation.dart';
import '../services/reliability_repository.dart';
import '../models/train_status.dart';

enum LoadStatus { initial, loading, loaded, error }



class ReliabilityFilter {
  final String? lineId;
  final String? stationId;

  const ReliabilityFilter({this.lineId, this.stationId});

  bool get isEmpty => lineId == null && stationId == null;
}

class ReliabilityProvider extends ChangeNotifier {
  final ReliabilityRepository _repository;
  final String userId;

  ReliabilityProvider({
    required ReliabilityRepository repository,
    required this.userId,
  }) : _repository = repository;



  LoadStatus status = LoadStatus.initial;
  String? errorMessage;

  ReliabilityFilter filter = const ReliabilityFilter();
  double? currentOnTimePercent;
  List<DailyOnTimeStat> trendSeries = [];
  List<TrainStatus> recentDelays = [];
  int actualDaysAvailable = 0;



  int get trendWindowDays => trendSeries.length;



  LoadStatus routeStatus = LoadStatus.initial;
  String? routeErrorMessage;
  List<RouteSuggestion> routeSuggestions = [];

  Future<void> loadDashboard(ReliabilityFilter newFilter) async {
    filter = newFilter;
    status = LoadStatus.loading;
    errorMessage = null;
    notifyListeners();

    try {



      final probe = await _repository.fetchReliabilitySummary(
        lineId: filter.lineId,
        stationId: filter.stationId,
        days: 3650,
      );
      actualDaysAvailable = probe.daysOfData;




      final windowDays = actualDaysAvailable <= 0
          ? 1
          : (actualDaysAvailable > 7 ? 7 : actualDaysAvailable);







      final summary = await _repository.fetchReliabilitySummary(
        lineId: filter.lineId,
        stationId: filter.stationId,
        days: windowDays,
      );
      currentOnTimePercent = summary.insufficientData ? null : summary.onTimePercentage;

      trendSeries = await _repository.fetchOnTimeStats(
        lineId: filter.lineId,
        stationId: filter.stationId,
        days: windowDays,
      );

      recentDelays = await _repository.fetchRecentTrainDelays(
        lineId: filter.lineId,
        stationId: filter.stationId,
        limit: 20,
      );

      status = LoadStatus.loaded;
    } catch (e) {
      errorMessage = e.toString();
      status = LoadStatus.error;
    }
    notifyListeners();
  }

  Future<void> loadRouteSuggestions() async {
    routeStatus = LoadStatus.loading;
    routeErrorMessage = null;
    notifyListeners();

    try {
      routeSuggestions = await _repository.fetchRouteSuggestionCandidates(userId);
      routeStatus = LoadStatus.loaded;
    } catch (e) {
      routeErrorMessage = e.toString();
      routeStatus = LoadStatus.error;
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    await Future.wait([
      loadDashboard(filter),
      loadRouteSuggestions(),
    ]);
  }
}
