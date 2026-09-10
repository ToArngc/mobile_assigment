import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ride_log.dart';
import '../models/weekly_ride_summary.dart';
import 'edge_function_client.dart';

class WeeklySummaryRepository {

  Future<WeeklyRideSummary> getWeeklySummary(String userId) async {
    try {
      final data = await invokeFunction('get-weekly-rides');
      return WeeklyRideSummary.fromJson(data as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to load ride logs: $e');
    }
  }

  Future<List<RideLog>> getRecentRides(String userId, {int limit = 10}) async {
    try {
      final data = await invokeFunction(
        'get-recent-rides',
        queryParameters: {'limit': '$limit'},
      );
      return (data as List)
          .map((row) => RideLog.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load ride history: $e');
    }
  }

  Future<void> logRide({
    required String userId,
    required String stationId,
    int? delayMinutes,
    String? destinationStationId,
    int? durationMinutes,
  }) async {
    try {
      await invokeFunction(
        'log-ride',
        method: HttpMethod.post,
        body: {
          'station_id': stationId,
          'delay_minutes': delayMinutes,
          'destination_station_id': destinationStationId,
          'duration_minutes': durationMinutes,
        },
      );
    } catch (e) {
      throw Exception('Failed to log ride: $e');
    }
  }
}
