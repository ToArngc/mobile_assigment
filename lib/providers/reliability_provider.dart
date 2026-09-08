import 'package:flutter/foundation.dart';
import '../services/reliability_repository.dart';
import '../models/train_status.dart';

enum LoadStatus { initial, loading, loaded, error }

/// Which line/station the Dashboard is currently scoped to. Both null means
/// "all lines, all stations".
class ReliabilityFilter {
  final String? lineId;
  final String? stationId;

  const ReliabilityFilter({this.lineId, this.stationId});
}

class ReliabilityProvider extends ChangeNotifier {
  final ReliabilityRepository _repository;
  final String userId;

  ReliabilityProvider({
    required ReliabilityRepository repository,
    required this.userId,
  }) : _repository = repository;

  // ---- Dashboard state ----

  LoadStatus status = LoadStatus.initial;
  String? errorMessage;

  ReliabilityFilter filter = const ReliabilityFilter();
  double? currentOnTimePercent; // null = no data at all for this filter
  List<DailyOnTimeStat> trendSeries = [];
  List<TrainStatus> recentDelays = [];
  int actualDaysAvailable = 0;

  /// Actual number of days the trend chart is showing (<=7) — drives the
  /// dynamic "N-day trend" label instead of a hardcoded "7-day trend".
  int get trendWindowDays => trendSeries.length;

  // ---- Route suggestion state ----

  LoadStatus routeStatus = LoadStatus.initial;
  String? routeErrorMessage;
  List<RouteSuggestion> routeSuggestions = [];

  Future<void> loadDashboard(ReliabilityFilter newFilter) async {
    filter = newFilter;
    status = LoadStatus.loading;
    errorMessage = null;
    notifyListeners();

    try {
      // Large window stands in for "all data" purely to size the trend
      // window below — the function requires an explicit days param and
      // there's no dedicated distinct-days endpoint.
      final probe = await _repository.fetchReliabilitySummary(
        lineId: filter.lineId,
        stationId: filter.stationId,
        days: 3650,
      );
      actualDaysAvailable = probe.daysOfData;

      // Always query at least a 1-day window so "since" isn't ~now when no
      // data exists yet — harmless either way since an empty table just
      // yields an empty trend, which the screen renders as an empty state.
      final windowDays = actualDaysAvailable <= 0
          ? 1
          : (actualDaysAvailable > 7 ? 7 : actualDaysAvailable);

      // Headline stats come straight from the aggregate endpoint's own
      // server-side computation (over this same windowDays), not folded
      // from trendSeries — trendSeries exists purely to feed the chart and
      // is legitimately empty for the no-filter case (no meaningful
      // "trend" for "all lines"), which must not blank out the summary
      // card too.
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
