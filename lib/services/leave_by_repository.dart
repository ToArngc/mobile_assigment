import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/saved_route.dart';
import 'edge_function_client.dart';
import 'supabase_service.dart';


class LeaveByResult {
  final DateTime nextScheduledDeparture;
  final double avgDelayMinutes;
  final bool hasEnoughData;
  final DateTime leaveByTime;
  final int sampleSize;

  LeaveByResult({
    required this.nextScheduledDeparture,
    required this.avgDelayMinutes,
    required this.hasEnoughData,
    required this.leaveByTime,
    required this.sampleSize,
  });

  factory LeaveByResult.fromJson(Map<String, dynamic> json) {
    return LeaveByResult(
      nextScheduledDeparture:
          DateTime.parse(json['next_scheduled_departure'] as String),
      avgDelayMinutes: (json['average_delay_minutes'] as num).toDouble(),
      hasEnoughData: json['has_enough_data'] as bool,
      leaveByTime: DateTime.parse(json['leave_by_time'] as String),
      sampleSize: (json['sample_size'] as num?)?.toInt() ?? 0,
    );
  }
}

class LeaveByRepository {



  Future<List<SavedRoute>> getSavedRoutes(String userId) async {
    try {
      // Read from the table so saved routes are available even while an older
      // version of the Edge Function is still deployed. The query remains
      // scoped to the signed-in user.
      final data = await SupabaseService.client
          .from('saved_routes')
          .select(
            '*, origin_station:stations!saved_routes_origin_station_id_fkey(name, line)',
          )
          .eq('user_id', userId)
          .not('origin_station_id', 'is', null)
          .order('created_at', ascending: false);
      return (data as List)
          .whereType<Map>()
          .map((row) => SavedRoute.tryFromJson(
                Map<String, dynamic>.from(row),
              ))
          .whereType<SavedRoute>()
          .toList();
    } catch (e) {
      throw Exception('Failed to load saved routes: $e');
    }
  }

  Future<SavedRoute> upsertSavedRoute(SavedRoute route) async {
    try {
      final body = <String, dynamic>{
        if (route.id.isNotEmpty) 'id': route.id,
        'origin_station_id': route.originStationId,
        if (route.destinationStationId != null)
          'destination_station_id': route.destinationStationId,
        'walking_minutes': route.walkingMinutes,
      };
      final data = await invokeFunction(
        'upsert-saved-route',
        method: HttpMethod.post,
        body: body,
      );
      return SavedRoute.fromJson(data as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to save route: $e');
    }
  }

  Future<void> deleteSavedRoute(String id) async {
    try {
      await invokeFunction(
        'delete-saved-route',
        method: HttpMethod.delete,
        body: {'id': id},
      );
    } catch (e) {
      throw Exception('Failed to remove route: $e');
    }
  }







  Future<LeaveByResult?> computeLeaveByTime(SavedRoute route) async {
    try {
      final data = await invokeFunction(
        'compute-leave-by-time',
        queryParameters: {'saved_route_id': route.id},
      );
      return data == null
          ? null
          : LeaveByResult.fromJson(data as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to compute leave-by time: $e');
    }
  }
}
