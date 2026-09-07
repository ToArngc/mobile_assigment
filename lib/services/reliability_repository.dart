import '../models/train_status.dart';
import 'edge_function_client.dart';

/// One calendar day's on-time performance. The trend chart still needs a
/// day-by-day series, and no Edge Function returns one (get-reliability-stats
/// returns a single aggregated window, not a series — see
/// ReliabilityRepository.fetchOnTimeStats), so this bucketing still happens
/// in Dart, just over rows fetched from get-recent-train-delays instead of
/// a direct `train_status` table read.
class DailyOnTimeStat {
  final DateTime date; // local calendar day, midnight
  final int onTimeCount;
  final int totalCount;

  DailyOnTimeStat({
    required this.date,
    required this.onTimeCount,
    required this.totalCount,
  });

  double get onTimePercent => totalCount == 0 ? 0 : onTimeCount / totalCount * 100;
}

enum RouteReliabilityStatus { onTrack, delayed, unreliable, notEnoughData }

/// One saved route's computed reliability, for the Route Suggestion screen.
/// Reshaped directly from get-route-suggestions' response — the trigger
/// logic (live delay wins regardless of the weekly stat; the weekly verdict
/// only applies once >=2 days of history exist; below 70% weekly on-time is
/// "unreliable") is now computed server-side, not in [status] locally.
class RouteSuggestion {
  final String routeId;
  final String originStationName;
  final String originLine;
  final String destinationStationName;
  final int daysOfData; // distinct days behind weeklyOnTimePercent, capped at 7
  final double? weeklyOnTimePercent; // null if no data at all
  final int? liveDelayMinutes; // most recent delay at origin, only if within last ~60 min
  final RouteReliabilityStatus status;
  final String? alternateLine;
  final double? alternateLineOnTimePercent;

  RouteSuggestion({
    required this.routeId,
    required this.originStationName,
    required this.originLine,
    required this.destinationStationName,
    required this.daysOfData,
    this.weeklyOnTimePercent,
    this.liveDelayMinutes,
    required this.status,
    this.alternateLine,
    this.alternateLineOnTimePercent,
  });

  factory RouteSuggestion.fromJson(Map<String, dynamic> json) {
    final route = json['route'] as Map<String, dynamic>? ?? const {};
    final alternative = json['suggested_alternative'] as Map<String, dynamic>?;
    return RouteSuggestion(
      routeId: route['id'] as String? ?? '',
      originStationName: json['origin_station_name'] as String? ?? 'Unknown station',
      originLine: json['origin_line'] as String? ?? '',
      destinationStationName:
          json['destination_station_name'] as String? ?? 'Unknown station',
      daysOfData: json['days_of_data'] as int? ?? 0,
      weeklyOnTimePercent: (json['weekly_on_time_percentage'] as num?)?.toDouble(),
      liveDelayMinutes: json['live_delay_minutes'] as int?,
      status: _statusFromString(json['status'] as String?),
      alternateLine: alternative?['line'] as String?,
      alternateLineOnTimePercent:
          (alternative?['on_time_percentage'] as num?)?.toDouble(),
    );
  }

  static RouteReliabilityStatus _statusFromString(String? value) {
    switch (value) {
      case 'delayed':
        return RouteReliabilityStatus.delayed;
      case 'unreliable':
        return RouteReliabilityStatus.unreliable;
      case 'on_track':
        return RouteReliabilityStatus.onTrack;
      case 'not_enough_data':
      default:
        return RouteReliabilityStatus.notEnoughData;
    }
  }
}

class ReliabilityRepository {
  /// A train is "on time" if it arrived within this many minutes of its
  /// scheduled time. Matches ON_TIME_THRESHOLD_MINUTES in
  /// supabase/functions/_shared/reliability.ts — change both together.
  static const int onTimeThresholdMinutes = 5;

  /// How many distinct calendar days (local time) have any train_status
  /// rows for this filter — the dashboard uses this to size its trend
  /// window instead of assuming a full week of history exists.
  ///
  /// get-reliability-stats requires station_id and/or line (400 with
  /// neither), but the Dashboard's default "all lines, all stations" view
  /// has neither filter set. So this only calls get-reliability-stats when
  /// at least one filter is present; the unfiltered case falls back to
  /// counting distinct days from get-recent-train-delays' raw rows, same
  /// technique as [fetchOnTimeStats]. Flagged as an open item: either relax
  /// get-reliability-stats' required-filter constraint, or confirm this
  /// fallback is acceptable long-term.
  Future<int> fetchDistinctDaysCount({String? lineId, String? stationId}) async {
    try {
      if (lineId == null && stationId == null) {
        final data = await invokeFunction(
          'get-recent-train-delays',
          queryParameters: {'limit': '2000'},
        );
        final days = (data as List)
            .map((row) => DateTime.parse((row as Map<String, dynamic>)['recorded_at'] as String)
                .toLocal())
            .map((dt) => DateTime(dt.year, dt.month, dt.day))
            .toSet();
        return days.length;
      }

      final data = await invokeFunction(
        'get-reliability-stats',
        queryParameters: {
          if (stationId != null) 'station_id': stationId,
          if (lineId != null) 'line': lineId,
          // Large window stands in for "all data" — the function requires
          // an explicit days param and there's no dedicated distinct-days
          // endpoint.
          'days': '3650',
        },
      );
      return (data as Map<String, dynamic>)['days_of_data'] as int? ?? 0;
    } catch (e) {
      throw Exception('Failed to load data availability: $e');
    }
  }

  /// Aggregates recent arrivals from get-recent-train-delays by local
  /// calendar day over the trailing [days] days: % of arrivals within
  /// [onTimeThresholdMinutes] vs total. [lineId] is the free-text value of
  /// train_status.line, matching StationRepository.getStationsByLine.
  Future<List<DailyOnTimeStat>> fetchOnTimeStats({
    String? lineId,
    String? stationId,
    required int days,
  }) async {
    try {
      final data = await invokeFunction(
        'get-recent-train-delays',
        queryParameters: {
          if (stationId != null) 'station_id': stationId,
          if (lineId != null) 'line': lineId,
          // Ordered/limited rather than date-bounded by wall-clock "now",
          // same reasoning as the pre-migration client query: if the
          // pipeline has gaps, the trend should still show the most recent
          // days that actually have data.
          'limit': '2000',
        },
      );

      final rows = (data as List)
          .map((row) => TrainStatus.fromJson(row as Map<String, dynamic>))
          .where((row) => row.delayMinutes != null)
          .toList();

      final byDay = <DateTime, List<TrainStatus>>{};
      for (final row in rows) {
        final local = row.recordedAt.toLocal();
        final day = DateTime(local.year, local.month, local.day);
        byDay.putIfAbsent(day, () => []).add(row);
      }

      final sortedDays = byDay.keys.toList()..sort();
      final recentDays =
          sortedDays.length > days ? sortedDays.sublist(sortedDays.length - days) : sortedDays;

      return recentDays.map((day) {
        final dayRows = byDay[day]!;
        final onTime = dayRows
            .where((r) => (r.delayMinutes ?? 0) <= onTimeThresholdMinutes)
            .length;
        return DailyOnTimeStat(date: day, onTimeCount: onTime, totalCount: dayRows.length);
      }).toList();
    } catch (e) {
      throw Exception('Failed to load on-time stats: $e');
    }
  }

  /// Recent individual arrivals for the per-train list — newest first.
  Future<List<TrainStatus>> fetchRecentTrainDelays({
    String? lineId,
    String? stationId,
    int limit = 20,
  }) async {
    try {
      final data = await invokeFunction(
        'get-recent-train-delays',
        queryParameters: {
          if (stationId != null) 'station_id': stationId,
          if (lineId != null) 'line': lineId,
          'limit': '$limit',
        },
      );
      return (data as List)
          .map((row) => TrainStatus.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load recent train delays: $e');
    }
  }

  /// One call to get-route-suggestions returns all of the caller's saved
  /// routes with their reliability already computed server-side — this
  /// used to be an N+1 loop (two extra queries per route, plus more per
  /// alternate line), now gone entirely. [userId] is kept in the signature
  /// but the function is JWT-scoped to the caller.
  Future<List<RouteSuggestion>> fetchRouteSuggestionCandidates(String userId) async {
    try {
      final data = await invokeFunction('get-route-suggestions');
      return (data as List)
          .map((row) => RouteSuggestion.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load route suggestions: $e');
    }
  }
}
