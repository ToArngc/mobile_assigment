import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/mute_settings.dart';
import '../models/saved_station.dart';
import '../models/train_status.dart';
import 'edge_function_client.dart';

class AlertsRepository {





  Future<List<SavedStation>> getSavedStations(String userId) async {
    try {
      final data = await invokeFunction('get-saved-stations');
      return (data as List)
          .map((row) => SavedStation.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load saved stations: $e');
    }
  }




  Future<void> setEnabled(String id, bool enabled) async {
    try {
      await invokeFunction(
        'toggle-saved-station',
        method: HttpMethod.patch,
        body: {'id': id, 'enabled': enabled},
      );
    } catch (e) {
      throw Exception('Failed to update alert rule: $e');
    }
  }





  Future<SavedStation> upsertSavedStation(SavedStation station) async {
    try {
      final body = <String, dynamic>{
        if (station.id.isNotEmpty) 'id': station.id,
        'station_id': station.stationId,
        'alert_delay_threshold': station.alertDelayThreshold,
        'quiet_hours_start': station.quietHoursStart,
        'quiet_hours_end': station.quietHoursEnd,
        'active_days': station.activeDays,
        'enabled': station.enabled,
      };
      final data = await invokeFunction(
        'upsert-saved-station',
        method: HttpMethod.post,
        body: body,
      );
      return SavedStation.fromJson(data as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to save alert rule: $e');
    }
  }

  Future<void> deleteSavedStation(String id) async {
    try {
      await invokeFunction(
        'delete-saved-station',
        method: HttpMethod.delete,
        body: {'id': id},
      );
    } catch (e) {
      throw Exception('Failed to remove saved station: $e');
    }
  }



  Future<TrainStatus?> getLatestTrainStatus(String stationId) async {
    try {
      final data = await invokeFunction(
        'get-latest-train-status',
        queryParameters: {'station_id': stationId},
      );
      return data == null
          ? null
          : TrainStatus.fromJson(data as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to load latest train status: $e');
    }
  }






  Future<MuteSettings?> getMuteSettings(String userId) async {
    try {
      final data = await invokeFunction('get-mute-settings');
      return data == null
          ? null
          : MuteSettings.fromJson(data as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to load mute settings: $e');
    }
  }




  Future<MuteSettings> setMute(String userId, DateTime? mutedUntil) async {
    try {
      final data = await invokeFunction(
        'set-mute-settings',
        method: HttpMethod.post,
        body: {
          'muted_until': mutedUntil?.toIso8601String().split('T').first,
        },
      );
      return MuteSettings.fromJson(data as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to update mute setting: $e');
    }
  }
}
