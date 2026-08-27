import '../../../core/supabase_client.dart';
import '../../../core/models/station.dart';
import '../../../core/models/timetable_entry.dart';

class StationRepository {
  final _client = SupabaseService.client;

  Future<List<Station>> getAllStations() async {
    final data = await _client.from('stations').select().order('name');
    return (data as List).map((row) => Station.fromJson(row)).toList();
  }

  Future<List<Station>> searchStations(String query) async {
    final data = await _client
        .from('stations')
        .select()
        .ilike('name', '%$query%');
    return (data as List).map((row) => Station.fromJson(row)).toList();
  }

  Future<Station?> getStationById(String id) async {
    final data =
        await _client.from('stations').select().eq('id', id).maybeSingle();
    return data != null ? Station.fromJson(data) : null;
  }

  Future<List<Station>> getStationsByLine(String line) async {
    final data = await _client.from('stations').select().eq('line', line);
    return (data as List).map((row) => Station.fromJson(row)).toList();
  }

  /// Returns the published timetable entries for a station, ordered by time.
  /// Keeping this query here lets the Explore screens stay independent of the
  /// backend implementation.
  Future<List<TimetableEntry>> getTimetableForStation(String stationId) async {
    final data = await _client
        .from('timetable_entries')
        .select()
        .eq('station_id', stationId)
        .order('scheduled_time');
    return (data as List)
        .map((row) => TimetableEntry.fromJson(row as Map<String, dynamic>))
        .toList();
  }
}
