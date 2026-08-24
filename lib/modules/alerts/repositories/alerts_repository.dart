import '../../../services/supabase_service.dart';
import '../../../models/saved_station.dart';
import '../../../models/mute_settings.dart';

class AlertsRepository {
  final _client = SupabaseService.client;

  // ---- Alert Rules (saved_stations) ----

  Future<List<SavedStation>> getSavedStations(String userId) async {
    try {
      // Join stations(name, line) so callers get real names instead of
      // just a station_id — the "My alerts" screen shows the station
      // name directly, not a uuid.
      final data = await _client
          .from('saved_stations')
          .select('*, stations(name, line)')
          .eq('user_id', userId);
      return (data as List)
          .map((row) => SavedStation.fromJson(row))
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
      await _client.from('saved_stations').update({'enabled': enabled}).eq('id', id);
    } catch (e) {
      throw Exception('Failed to update alert rule: $e');
    }
  }

  /// Creates or updates an alert rule for a station.
  /// If station.id is empty, this is a new row — omit 'id' entirely so
  /// Postgres generates the uuid itself (an empty string is not a valid
  /// uuid and would be rejected).
  Future<SavedStation> upsertSavedStation(SavedStation station) async {
    try {
      final json = station.toJson();
      if (station.id.isEmpty) {
        json.remove('id');
      }
      final data = await _client
          .from('saved_stations')
          .upsert(json)
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