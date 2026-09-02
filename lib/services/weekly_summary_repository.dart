import 'supabase_service.dart';
import '../models/ride_log.dart';

/// Threshold used to define "on-time" for the on-time % stat.
/// Matches the default alert threshold used elsewhere in Module 4 —
/// keep these in sync if either changes.
const int kOnTimeDelayThresholdMinutes = 5;

class WeeklySummaryRepository {
  final _client = SupabaseService.client;

  /// Rides detected for [userId] in the last 7 days.
  Future<List<RideLog>> getRidesForLastWeek(String userId) async {
    try {
      final since = DateTime.now().subtract(const Duration(days: 7));
      final data = await _client
          .from('ride_logs')
          .select()
          .eq('user_id', userId)
          .gte('detected_at', since.toIso8601String())
          .order('detected_at');
      return (data as List).map((row) => RideLog.fromJson(row)).toList();
    } catch (e) {
      throw Exception('Failed to load ride logs: $e');
    }
  }

  /// Most recent rides, joined with station name/line for display —
  /// used by the "Ride history" section on the Alerts Home screen.
  /// Also joins the destination station's name when the ride was closed
  /// out (see [RideLog.hasFullTripDetail]) — rides that never got a
  /// second station detected will have a null destination, and the UI
  /// should fall back to showing just the origin for those.
  Future<List<RideLog>> getRecentRides(String userId, {int limit = 10}) async {
    try {
      final data = await _client
          .from('ride_logs')
          .select(
              '*, stations!ride_logs_station_id_fkey(name, line), destination_station:stations!ride_logs_destination_station_id_fkey(name)')
          .eq('user_id', userId)
          .order('detected_at', ascending: false)
          .limit(limit);
      return (data as List).map((row) => RideLog.fromJson(row)).toList();
    } catch (e) {
      throw Exception('Failed to load ride history: $e');
    }
  }

  /// Records a detected ride in one INSERT. Called when the app is open,
  /// during commute hours, and the user is near a known station — see the
  /// foreground detection limitation noted in the Module 4 design doc:
  /// this can only catch rides while the app is actually open.
  ///
  /// [destinationStationId] and [durationMinutes] are optional and
  /// written together with the origin in a single row -- this is
  /// deliberate: the design doc's RLS policy for ride_logs only grants
  /// SELECT and INSERT for a user's own rows (no UPDATE), so a ride can't
  /// be logged as "open" and patched with a destination later. The
  /// caller (RideDetectionService) is responsible for holding ride state
  /// in memory until it either detects a destination or gives up, and
  /// only then calling this once.
  Future<void> logRide({
    required String userId,
    required String stationId,
    int? delayMinutes,
    String? destinationStationId,
    int? durationMinutes,
  }) async {
    try {
      await _client.from('ride_logs').insert({
        'user_id': userId,
        'station_id': stationId,
        'detected_at': DateTime.now().toIso8601String(),
        'delay_minutes': delayMinutes,
        'destination_station_id': destinationStationId,
        'duration_minutes': durationMinutes,
      });
    } catch (e) {
      throw Exception('Failed to log ride: $e');
    }
  }
}