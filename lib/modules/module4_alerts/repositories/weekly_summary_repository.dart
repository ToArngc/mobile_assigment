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

  /// Records a detected ride. Called when the app is open, during commute
  /// hours, and the user is near a known station — see the foreground
  /// detection limitation noted in the Module 4 design doc: this can only
  /// catch rides while the app is actually open.
  Future<void> logRide({
    required String userId,
    required String stationId,
    int? delayMinutes,
  }) async {
    try {
      await _client.from('ride_logs').insert({
        'user_id': userId,
        'station_id': stationId,
        'detected_at': DateTime.now().toIso8601String(),
        'delay_minutes': delayMinutes,
      });
    } catch (e) {
      throw Exception('Failed to log ride: $e');
    }
  }
}