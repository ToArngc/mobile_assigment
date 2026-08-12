import '../../../core/supabase_client.dart';
import '../../../core/models/saved_station.dart';
import '../../../core/models/mute_settings.dart';

class AlertsRepository {
  final _client = SupabaseService.client;

  // ---- Alert Rules (saved_stations) ----

  Future<List<SavedStation>> getSavedStations(String userId) async {
    try {
      final data = await _client
          .from('saved_stations')
          .select()
          .eq('user_id', userId);
      return (data as List)
          .map((row) => SavedStation.fromJson(row))
          .toList();
    } catch (e) {
      throw Exception('Failed to load saved stations: $e');
    }
  }

  /// Creates or updates an alert rule for a station.
  Future<SavedStation> upsertSavedStation(SavedStation station) async {
    try {
      final data = await _client
          .from('saved_stations')
          .upsert(station.toJson())
          .select()
          .single();
      return SavedStation.fromJson(data);
    } catch (e) {
      throw Exception('Failed to save alert rule: $e');
    }
  }

  Future<void> deleteSavedStation(String id) async {
    try {
      await _client.from('saved_stations').delete().eq('id', id);
    } catch (e) {
      throw Exception('Failed to remove saved station: $e');
    }
  }

  // ---- Quick Mute (mute_settings) ----

  Future<MuteSettings?> getMuteSettings(String userId) async {
    try {
      final data = await _client
          .from('mute_settings')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      return data != null ? MuteSettings.fromJson(data) : null;
    } catch (e) {
      throw Exception('Failed to load mute settings: $e');
    }
  }

  /// mutedUntil = null clears the mute ("No Commute Today" toggled back off,
  /// or the muted-until date has passed).
  Future<MuteSettings> setMute(String userId, DateTime? mutedUntil) async {
    try {
      final data = await _client
          .from('mute_settings')
          .upsert({
        'user_id': userId,
        'muted_until': mutedUntil?.toIso8601String().split('T').first,
        'updated_at': DateTime.now().toIso8601String(),
      })
          .select()
          .single();
      return MuteSettings.fromJson(data);
    } catch (e) {
      throw Exception('Failed to update mute setting: $e');
    }
  }
}