import '../models/station.dart';
import '../models/station_accessibility.dart';
import '../models/train_status.dart';
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

  /// Live accessibility status for a station, newest report per issue
  /// type, from the station_accessibility view. An empty list means
  /// nothing has been reported — a good state, not a failure.
  Future<List<StationAccessibility>> getStationAccessibility(
      String stationId) async {
    final data = await invokeFunction(
      'get-station-accessibility',
      queryParameters: {'station_id': stationId},
    );
    return (data as List)
        .map((row) =>
            StationAccessibility.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// The latest train_status row per station along one line, bounded
  /// server-side to recent readings. Backs Module 1's live schematic.
  /// Returns an empty list when no train has been seen on the line
  /// recently — the caller must say so rather than invent a position.
  Future<List<TrainStatus>> getLiveTrainStatusForLine(String line) async {
    final data = await invokeFunction(
      'get-latest-train-status',
      queryParameters: {'line': line},
    );
    return (data as List)
        .map((row) => TrainStatus.fromJson(row as Map<String, dynamic>))
        .toList();
  }
}
