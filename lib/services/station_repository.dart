import '../models/station.dart';
import '../models/timetable_entry.dart';
import 'supabase_service.dart';

/// Shared station access for Explore, Reports, and Alerts.
class StationRepository {
  final _client = SupabaseService.client;

  Future<List<Station>> getAllStations() async {
    final data = await _client.from('stations').select().order('name');
    return (data as List)
        .map((row) => Station.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<Station>> searchStations(String query) async {
    final data = await _client
        .from('stations')
        .select()
        .ilike('name', '%$query%')
        .order('name');
    return (data as List)
        .map((row) => Station.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<Station?> getStationById(String id) async {
    final data = await _client.from('stations').select().eq('id', id).maybeSingle();
    return data == null ? null : Station.fromJson(data);
  }

  Future<List<Station>> getStationsByLine(String line) async {
    final data = await _client.from('stations').select().eq('line', line);
    return (data as List)
        .map((row) => Station.fromJson(row as Map<String, dynamic>))
        .toList();
  }

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
