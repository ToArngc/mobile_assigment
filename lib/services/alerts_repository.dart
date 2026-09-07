import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/mute_settings.dart';
import '../models/saved_station.dart';
import '../models/train_status.dart';
import 'edge_function_client.dart';

class AlertsRepository {
  // ---- Alert Rules (saved_stations) ----

  /// get-saved-stations is JWT-scoped to the caller — [userId] is kept in
  /// the signature for existing callers but must always be the current
  /// user's own id.
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

  /// Quick on/off toggle for the switch in the "My alerts" list — pauses
  /// the alert without discarding the threshold/quiet-hours/active-days
  /// settings underneath (those still need the full editor to change).
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

  /// Creates or updates an alert rule for a station.
  /// If station.id is empty, this is a new row — upsert-saved-station
  /// treats a missing id as "create", and always forces user_id to the
  /// caller server-side regardless of what's in the body.
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

  /// Most recent status reported for one saved station. A null delay is a
  /// valid status record but cannot produce a delay alert.
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

  // ---- Quick Mute (mute_settings) ----

  /// get-mute-settings is JWT-scoped to the caller — [userId] is kept in
  /// the signature for existing callers but must always be the current
  /// user's own id.
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

  /// mutedUntil = null clears the mute ("No Commute Today" toggled back off,
  /// or the muted-until date has passed). [userId] is kept in the signature
  /// but set-mute-settings always upserts for the JWT-authenticated caller.
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
