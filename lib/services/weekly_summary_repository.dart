import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ride_log.dart';
import '../models/weekly_ride_summary.dart';
import 'edge_function_client.dart';

class WeeklySummaryRepository {
  /// This week's rides with the on-time percentage and average delay
  /// already aggregated server-side. get-weekly-rides is JWT-scoped to
  /// the caller — [userId] is kept in the signature for existing callers
  /// but must always be the current user's own id.
  Future<WeeklyRideSummary> getWeeklySummary(String userId) async {
    try {
      final data = await invokeFunction('get-weekly-rides');
      return WeeklyRideSummary.fromJson(data as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to load ride logs: $e');
    }
  }

  /// Most recent rides, joined with station name/line for display — used
  /// by the "Ride history" section on the Alerts Home screen. [userId] is
  /// kept in the signature but get-recent-rides is JWT-scoped to the
  /// caller.
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

  /// Records a detected ride in one call. [userId] is kept in the
  /// signature but log-ride always forces user_id to the JWT-authenticated
  /// caller server-side.
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
