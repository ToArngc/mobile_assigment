import '../../../services/supabase_service.dart';
import '../../../models/station.dart';

//just dome
class StationRepository {
  final _client = SupabaseService.client;

  Future<List<Station>> getAllStations() async {
    final data = await _client.from('stations').select();
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
}
