import '../models/station.dart';
import '../models/station_accessibility.dart';
import '../models/train_status.dart';
import '../models/timetable_entry.dart';
import 'edge_function_client.dart';


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
