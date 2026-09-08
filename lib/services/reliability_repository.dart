import '../models/train_status.dart';
import 'edge_function_client.dart';

/// One calendar day's on-time performance, from get-reliability-trend — the
/// day bucketing happens in Postgres now (see
/// ReliabilityRepository.fetchOnTimeStats), not client-side.
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

/// Aggregate reliability numbers for one station/line filter (or
/// network-wide when both are omitted), straight from
/// get-reliability-stats' / get-network-reliability-stats' own server-side
/// aggregation — the values are computed by the reliability_stats() RPC,
/// never folded from [DailyOnTimeStat] rows client-side.
class ReliabilityStatsSummary {
  final int daysOfData;
  final double? onTimePercentage; // null when insufficientData
  final double? averageDelayMinutes; // null when insufficientData
  final int totalTrips;
  final bool insufficientData;

  ReliabilityStatsSummary({
    required this.daysOfData,
    this.onTimePercentage,
    this.averageDelayMinutes,
    required this.totalTrips,
    required this.insufficientData,
  });
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
  /// Aggregate stats for this filter (or network-wide if both are
  /// omitted) over the trailing [days] days — total_trips,
  /// on_time_percentage, average_delay_minutes, days_of_data,
  /// insufficient_data, all computed server-side by the same RPC that
  /// backs get-reliability-stats.
  ///
  /// get-reliability-stats requires station_id and/or line (400 with
  /// neither), but the Dashboard's default "all lines, all stations" view
  /// has neither filter set. So this calls get-network-reliability-stats,
  /// the network-wide counterpart, for that case, and get-reliability-stats
  /// otherwise.
  Future<ReliabilityStatsSummary> fetchReliabilitySummary({
    String? lineId,
    String? stationId,
    required int days,
  }) async {
    try {
      final data = await invokeFunction(
        lineId == null && stationId == null
            ? 'get-network-reliability-stats'
            : 'get-reliability-stats',
        queryParameters: {
          if (stationId != null) 'station_id': stationId,
          if (lineId != null) 'line': lineId,
          'days': '$days',
        },
      );
      final map = data as Map<String, dynamic>;
      return ReliabilityStatsSummary(
        daysOfData: map['days_of_data'] as int? ?? 0,
        onTimePercentage: (map['on_time_percentage'] as num?)?.toDouble(),
        averageDelayMinutes: (map['average_delay_minutes'] as num?)?.toDouble(),
        totalTrips: map['total_trips'] as int? ?? 0,
        insufficientData: map['insufficient_data'] as bool? ?? true,
      );
    } catch (e) {
      throw Exception('Failed to load data availability: $e');
    }
  }

  /// Day-by-day on-time series over the trailing [days] days, from
  /// get-reliability-trend (day bucketing now happens in Postgres, not
  /// client-side). [lineId] is the free-text value of train_status.line,
  /// matching StationRepository.getStationsByLine.
  ///
  /// get-reliability-trend requires station_id and/or line, same as
  /// get-reliability-stats, so the Dashboard's default "all lines, all
  /// stations" view — which has neither — has no per-day trend available;
  /// this returns an empty list for that case rather than calling an
  /// endpoint that would 400. The Dashboard already renders an empty state
  /// when the series comes back empty.
  Future<List<DailyOnTimeStat>> fetchOnTimeStats({
    String? lineId,
    String? stationId,
    required int days,
  }) async {
    if (lineId == null && stationId == null) return [];

    try {
      final data = await invokeFunction(
        'get-reliability-trend',
        queryParameters: {
          if (stationId != null) 'station_id': stationId,
          if (lineId != null) 'line': lineId,
          'days': '$days',
        },
      );

      return (data as List).map((row) {
        final map = row as Map<String, dynamic>;
        return DailyOnTimeStat(
          date: DateTime.parse(map['day'] as String),
          onTimeCount: map['on_time_trips'] as int? ?? 0,
          totalCount: map['total_trips'] as int? ?? 0,
        );
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
