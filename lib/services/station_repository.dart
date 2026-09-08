import '../models/station.dart';
import '../models/timetable_entry.dart';
import 'edge_function_client.dart';

/// Shared station access for Explore, Reports, and Alerts.
class StationRepository {
  Future<List<Station>> getAllStations() async {
    final data = await invokeFunction('get-stations');
    return (data as List)
        .map((row) => Station.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<Station>> searchStations(String query) async {
    final data = await invokeFunction(
      'search-stations',
      queryParameters: {'q': query},
    );
    return (data as List)
        .map((row) => Station.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<Station?> getStationById(String id) async {
    try {
      final data = await invokeFunction(
        'get-station',
        queryParameters: {'id': id},
      );
      return Station.fromJson(data as Map<String, dynamic>);
    } on Exception catch (e) {
      // get-station 404s with "Station not found" instead of the old
      // .maybeSingle()'s plain null — recover the nullable-return
      // contract this method has always had.
      if (e.toString() == 'Exception: Station not found') return null;
      rethrow;
    }
  }

  Future<List<Station>> getStationsByLine(String line) async {
    final data = await invokeFunction(
      'get-stations-by-line',
      queryParameters: {'line': line},
    );
    return (data as List)
        .map((row) => Station.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<TimetableEntry>> getTimetableForStation(String stationId) async {
    final data = await invokeFunction(
      'get-station-timetable',
      queryParameters: {'station_id': stationId},
    );
    return (data as List)
        .map((row) => TimetableEntry.fromJson(row as Map<String, dynamic>))
        .toList();
  }
}
