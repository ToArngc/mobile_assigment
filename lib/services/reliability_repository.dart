import 'supabase_service.dart';
import '../models/train_status.dart';
import '../models/saved_route.dart';
import '../models/station.dart';

/// One calendar day's on-time performance, aggregated client-side from
/// train_status rows (mirrors LeaveByRepository's client-side average —
/// no RPC functions used elsewhere in this codebase).
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
class RouteSuggestion {
  final SavedRoute route;
  final String originStationName;
  final String originLine;
  final String destinationStationName;
  final int daysOfData; // distinct days behind weeklyOnTimePercent, capped at 7
  final double? weeklyOnTimePercent; // null if no data at all
  final int? liveDelayMinutes; // most recent delay at origin, only if within last ~60 min
  final String? alternateLine;
  final double? alternateLineOnTimePercent;

  RouteSuggestion({
    required this.route,
    required this.originStationName,
    required this.originLine,
    required this.destinationStationName,
    required this.daysOfData,
    this.weeklyOnTimePercent,
    this.liveDelayMinutes,
    this.alternateLine,
    this.alternateLineOnTimePercent,
  });

  /// Trigger logic per design doc §7: live delay wins regardless of the
  /// weekly stat; the weekly verdict only applies once >=2 days of history
  /// exist, otherwise there isn't enough signal to call a route unreliable.
  RouteReliabilityStatus get status {
    if (liveDelayMinutes != null &&
        liveDelayMinutes! > ReliabilityRepository.onTimeThresholdMinutes) {
      return RouteReliabilityStatus.delayed;
    }
    if (daysOfData < 2) return RouteReliabilityStatus.notEnoughData;
    if (weeklyOnTimePercent != null && weeklyOnTimePercent! < 70) {
      return RouteReliabilityStatus.unreliable;
    }
    return RouteReliabilityStatus.onTrack;
  }
}

class ReliabilityRepository {
  final _client = SupabaseService.client;

  /// A train is "on time" if it arrived within this many minutes of its
  /// scheduled time. Single named constant per design doc §7 — change this
  /// one value to retune the whole module.
  static const int onTimeThresholdMinutes = 5;

  /// How many distinct calendar days (local time) have any train_status
  /// rows for this filter — the dashboard uses this to size its trend
  /// window instead of assuming a full week of history exists.
  Future<int> fetchDistinctDaysCount({String? lineId, String? stationId}) async {
    try {
      var query = _client.from('train_status').select('recorded_at');
      if (lineId != null) query = query.eq('line', lineId);
      if (stationId != null) query = query.eq('station_id', stationId);
      final data = await query;

      final days = (data as List)
          .map((row) => DateTime.parse(row['recorded_at'] as String).toLocal())
          .map((dt) => DateTime(dt.year, dt.month, dt.day))
          .toSet();
      return days.length;
    } catch (e) {
      throw Exception('Failed to load data availability: $e');
    }
  }

  /// Aggregates train_status by local calendar day over the trailing [days]
  /// days: % of arrivals within [onTimeThresholdMinutes] vs total. [lineId]
  /// is the free-text value of train_status.line (there's no separate lines
  /// table), matching StationRepository.getStationsByLine.
  Future<List<DailyOnTimeStat>> fetchOnTimeStats({
    String? lineId,
    String? stationId,
    required int days,
  }) async {
    try {
      final since = DateTime.now().toUtc().subtract(Duration(days: days));
      var query = _client
          .from('train_status')
          .select()
          .not('delay_minutes', 'is', null)
          .gte('recorded_at', since.toIso8601String());
      if (lineId != null) query = query.eq('line', lineId);
      if (stationId != null) query = query.eq('station_id', stationId);
      final data = await query.order('recorded_at');

      final rows = (data as List)
          .map((row) => TrainStatus.fromJson(row as Map<String, dynamic>))
          .toList();

      final byDay = <DateTime, List<TrainStatus>>{};
      for (final row in rows) {
        final local = row.recordedAt.toLocal();
        final day = DateTime(local.year, local.month, local.day);
        byDay.putIfAbsent(day, () => []).add(row);
      }

      final sortedDays = byDay.keys.toList()..sort();
      return sortedDays.map((day) {
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
      var query = _client.from('train_status').select();
      if (lineId != null) query = query.eq('line', lineId);
      if (stationId != null) query = query.eq('station_id', stationId);
      final data = await query.order('recorded_at', ascending: false).limit(limit);
      return (data as List)
          .map((row) => TrainStatus.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load recent train delays: $e');
    }
  }

  /// Joins saved_routes with a computed weekly on-time % + most recent live
  /// delay for each route's origin station, plus the best-performing
  /// alternate line at that station (if it's an interchange). One saved
  /// route means a handful of extra queries here — fine at this data scale,
  /// not worth a batched RPC for a student project.
  Future<List<RouteSuggestion>> fetchRouteSuggestionCandidates(String userId) async {
    try {
      final data = await _client
          .from('saved_routes')
          .select(
            '*, origin_station:stations!saved_routes_origin_station_id_fkey(name, line), '
            'destination_station:stations!saved_routes_destination_station_id_fkey(name, line)',
          )
          .eq('user_id', userId);

      final suggestions = <RouteSuggestion>[];
      for (final row in (data as List)) {
        final json = row as Map<String, dynamic>;
        final route = SavedRoute.fromJson(json);
        final originStation = json['origin_station'] as Map<String, dynamic>?;
        final destinationStation = json['destination_station'] as Map<String, dynamic>?;

        // Station.lines splits a station's (possibly comma/slash-joined)
        // `line` field — reused here rather than duplicating that regex.
        // Only `line` is used from this dummy Station, so the other
        // required fields are just placeholders.
        final originLineField = originStation?['line'] as String? ?? '';
        final originLines = Station(
          id: route.originStationId,
          name: '',
          line: originLineField,
          lat: 0,
          lng: 0,
        ).lines;
        final primaryLine = originLines.isNotEmpty ? originLines.first : originLineField;

        final stats = await fetchOnTimeStats(stationId: route.originStationId, days: 7);
        final daysOfData = stats.length;
        final totalCount = stats.fold<int>(0, (sum, s) => sum + s.totalCount);
        final onTimeCount = stats.fold<int>(0, (sum, s) => sum + s.onTimeCount);
        final weeklyOnTimePercent = totalCount == 0 ? null : onTimeCount / totalCount * 100;

        final recent = await fetchRecentTrainDelays(stationId: route.originStationId, limit: 1);
        int? liveDelayMinutes;
        if (recent.isNotEmpty) {
          final latest = recent.first;
          final minutesAgo = DateTime.now().toUtc().difference(latest.recordedAt.toUtc()).inMinutes;
          if (minutesAgo <= 60) liveDelayMinutes = latest.delayMinutes;
        }

        String? alternateLine;
        double? alternateLineOnTimePercent;
        for (final line in originLines.where((l) => l != primaryLine)) {
          final lineStats = await fetchOnTimeStats(
            lineId: line,
            stationId: route.originStationId,
            days: 7,
          );
          final lineTotal = lineStats.fold<int>(0, (sum, s) => sum + s.totalCount);
          if (lineTotal == 0) continue;
          final lineOnTime = lineStats.fold<int>(0, (sum, s) => sum + s.onTimeCount);
          final pct = lineOnTime / lineTotal * 100;
          if (alternateLineOnTimePercent == null || pct > alternateLineOnTimePercent) {
            alternateLine = line;
            alternateLineOnTimePercent = pct;
          }
        }

        suggestions.add(RouteSuggestion(
          route: route,
          originStationName: originStation?['name'] as String? ?? 'Unknown station',
          originLine: primaryLine,
          destinationStationName: destinationStation?['name'] as String? ?? 'Unknown station',
          daysOfData: daysOfData,
          weeklyOnTimePercent: weeklyOnTimePercent,
          liveDelayMinutes: liveDelayMinutes,
          alternateLine: alternateLine,
          alternateLineOnTimePercent: alternateLineOnTimePercent,
        ));
      }

      return suggestions;
    } catch (e) {
      throw Exception('Failed to load route suggestions: $e');
    }
  }
}
