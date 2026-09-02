import 'supabase_service.dart';
import '../models/saved_route.dart';

/// Result of computing when the user needs to leave for a saved route.
class LeaveByResult {
  final DateTime nextScheduledDeparture;
  final double avgDelayMinutes;
  final bool hasEnoughData; // false if no train_status history exists yet
  final DateTime leaveByTime;

  LeaveByResult({
    required this.nextScheduledDeparture,
    required this.avgDelayMinutes,
    required this.hasEnoughData,
    required this.leaveByTime,
  });
}

class LeaveByRepository {
  final _client = SupabaseService.client;

  Future<List<SavedRoute>> getSavedRoutes(String userId) async {
    try {
      final data = await _client
          .from('saved_routes')
          .select()
          .eq('user_id', userId);
      return (data as List).map((row) => SavedRoute.fromJson(row)).toList();
    } catch (e) {
      throw Exception('Failed to load saved routes: $e');
    }
  }

  Future<SavedRoute> upsertSavedRoute(SavedRoute route) async {
    try {
      final data = await _client
          .from('saved_routes')
          .upsert(route.toJson())
          .select()
          .single();
      return SavedRoute.fromJson(data);
    } catch (e) {
      throw Exception('Failed to save route: $e');
    }
  }

  Future<void> deleteSavedRoute(String id) async {
    try {
      await _client.from('saved_routes').delete().eq('id', id);
    } catch (e) {
      throw Exception('Failed to remove route: $e');
    }
  }

  /// Combines the next scheduled departure from the origin station,
  /// the historical average delay at that station, and the user's
  /// walking time, into a single "leave by" time.
  ///
  /// Returns null if there's no upcoming scheduled departure today for
  /// this station (e.g. timetable_entries hasn't been imported yet, or
  /// the last train for today has already gone).
  Future<LeaveByResult?> computeLeaveByTime(SavedRoute route) async {
    final now = DateTime.now();
    final nowTimeString =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:00';

    // Next scheduled departure today from the origin station.
    final timetableRows = await _client
        .from('timetable_entries')
        .select()
        .eq('station_id', route.originStationId)
        .gte('scheduled_time', nowTimeString)
        .order('scheduled_time')
        .limit(1);

    if ((timetableRows as List).isEmpty) return null;

    final scheduledTimeStr = timetableRows.first['scheduled_time'] as String;
    final parts = scheduledTimeStr.split(':');
    final scheduledDeparture = DateTime(
      now.year, now.month, now.day,
      int.parse(parts[0]), int.parse(parts[1]),
    );

    // Historical average delay at this station (recent records).
    final delayRows = await _client
        .from('train_status')
        .select('delay_minutes')
        .eq('station_id', route.originStationId)
        .not('delay_minutes', 'is', null)
        .order('recorded_at', ascending: false)
        .limit(30);

    final delays = (delayRows as List)
        .map((r) => r['delay_minutes'] as int?)
        .whereType<int>()
        .toList();

    final hasEnoughData = delays.isNotEmpty;
    final avgDelay = hasEnoughData
        ? delays.reduce((a, b) => a + b) / delays.length
        : 0.0;

    final arriveByTime = scheduledDeparture.add(
      Duration(minutes: avgDelay.round()),
    );
    final leaveByTime = arriveByTime.subtract(
      Duration(minutes: route.walkingMinutes),
    );

    return LeaveByResult(
      nextScheduledDeparture: scheduledDeparture,
      avgDelayMinutes: avgDelay,
      hasEnoughData: hasEnoughData,
      leaveByTime: leaveByTime,
    );
  }
}