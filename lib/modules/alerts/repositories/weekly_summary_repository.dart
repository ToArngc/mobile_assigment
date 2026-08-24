import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/supabase_service.dart';
import '../../../models/ride_log.dart';


const int kOnTimeDelayThresholdMinutes = 5;

class WeeklySummaryRepository {
  final SupabaseClient _client;

  WeeklySummaryRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  static const _tableName = 'ride_logs';


  Future<List<RideLog>> getRidesForLastWeek(String userId, {DateTime? now}) async {
    try {
      const sevenDays = Duration(days: 7);
      final since = (now ?? DateTime.now()).subtract(sevenDays);
      final data = await _client
          .from(_tableName)
          .select()
          .eq('user_id', userId)
          .gte('detected_at', since.toIso8601String())
          .order('detected_at');

      return _parseRideLogs(data);
    } catch (e) {
      throw Exception('Failed to load ride logs for last week: $e');
    }
  }


  Future<List<RideLog>> getRecentRides(String userId, {int limit = 10}) async {
    try {
      final data = await _client
          .from(_tableName)
          .select(
            '*, '
            'stations!ride_logs_station_id_fkey(name, line), '
            'destination_station:stations!ride_logs_destination_station_id_fkey(name)',
          )
          .eq('user_id', userId)
          .order('detected_at', ascending: false)
          .limit(limit);

      return _parseRideLogs(data);
    } catch (e) {
      throw Exception('Failed to load recent ride history: $e');
    }
  }

  /// Logs a ride event.
  Future<void> logRide({
    required String userId,
    required String stationId,
    int? delayMinutes,
    String? destinationStationId,
    int? durationMinutes,
    DateTime? detectedAt,
  }) async {
    try {
      await _client.from(_tableName).insert({
        'user_id': userId,
        'station_id': stationId,
        'detected_at': (detectedAt ?? DateTime.now()).toIso8601String(),
        'delay_minutes': delayMinutes,
        'destination_station_id': destinationStationId,
        'duration_minutes': durationMinutes,
      });
    } catch (e) {
      throw Exception('Failed to log ride: $e');
    }
  }

  /// Shared logic for mapping raw Supabase data to [RideLog] instances.
  List<RideLog> _parseRideLogs(dynamic data) {
    if (data == null) return [];
    return (data as List).map((row) => RideLog.fromJson(row as Map<String, dynamic>)).toList();
  }
}
