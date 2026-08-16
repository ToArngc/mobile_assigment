import '../../../core/supabase_client.dart';
import '../../../core/models/ride_log.dart';

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
  /// Note: this only shows what ride_logs actually captures (station,
  /// delay, timestamp) — no destination or trip duration, since those
  /// aren't tracked yet. See the design note about extending ride_logs
  /// if the team wants to match the full "origin → destination, Xmin"
  /// mockup layout.
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

  /// Records a detected ride's origin. Called when the app is open, during
  /// commute hours, and the user is near a known station — see the
  /// foreground detection limitation noted in the Module 4 design doc:
  /// this can only catch rides while the app is actually open.
  ///
  /// Returns the new row's id so [closeOutRide] can attach a destination
  /// later in the same ride-detection session.
  Future<String> logRide({
    required String userId,
    required String stationId,
    int? delayMinutes,
  }) async {
    try {
      final row = await _client
          .from('ride_logs')
          .insert({
        'user_id': userId,
        'station_id': stationId,
        'detected_at': DateTime.now().toIso8601String(),
        'delay_minutes': delayMinutes,
      })
          .select('id')
          .single();
      return row['id'] as String;
    } catch (e) {
      throw Exception('Failed to log ride: $e');
    }
  }

  /// Attaches a destination + duration to a ride logged earlier via
  /// [logRide], once the rider is detected near a second station.
  /// Rides that never get closed out (app closed mid-commute, etc) simply
  /// keep destination_station_id = NULL -- the UI falls back to showing
  /// just the origin for those.
  Future<void> closeOutRide({
    required String rideLogId,
    required String destinationStationId,
    required int durationMinutes,
  }) async {
    try {
      await _client.from('ride_logs').update({
        'destination_station_id': destinationStationId,
        'duration_minutes': durationMinutes,
      }).eq('id', rideLogId);
    } catch (e) {
      throw Exception('Failed to close out ride: $e');
    }
  }
}