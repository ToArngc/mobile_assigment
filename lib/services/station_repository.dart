import '../models/station.dart';
import '../models/timetable_entry.dart';
import '../models/train_status.dart';
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

  /// Reads the station_accessibility view through its public Edge Function.
  /// Keeping this out of the station query avoids depending on a retired
  /// stations.accessibility_features column.
  Future<Map<String, dynamic>?> getStationAccessibility(String stationId) async {
    final response = await _client.functions.invoke(
      'get-station-accessibility',
      body: {'station_id': stationId},
    );
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final nested = data['data'];
      if (nested is Map<String, dynamic>) return nested;
      if (nested is List && nested.isNotEmpty && nested.first is Map) {
        return Map<String, dynamic>.from(nested.first as Map);
      }
      return data;
    }
    if (data is List && data.isNotEmpty && data.first is Map) {
      return Map<String, dynamic>.from(data.first as Map);
    }
    return null;
  }

  /// Gets the current train snapshots from the Edge Function, rather than
  /// querying train_status directly.
  Future<List<TrainStatus>> getLatestTrainStatus({required String line}) async {
    final response = await _client.functions.invoke(
      'get-latest-train-status',
      queryParameters: {'line': line},
    );
    final data = response.data;
    final rows = data is List
        ? data
        : data is Map<String, dynamic> && data['data'] is List
            ? data['data'] as List
            : const <dynamic>[];
    return rows
        .whereType<Map>()
        .map((row) => TrainStatus.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }
}
