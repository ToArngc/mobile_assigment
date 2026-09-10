import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/station.dart';
import '../models/station_accessibility.dart';
import '../models/train_status.dart';
import '../models/timetable_entry.dart';
import 'edge_function_client.dart';


class StationRepository {
  static const _cacheKey = 'stations_cache_v1';
  static const _cacheAtKey = 'stations_cache_at_v1';
  static const _cacheMaxAge = Duration(hours: 24);

  Future<List<Station>> getAllStations() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cacheKey);
    final cachedAt = DateTime.tryParse(prefs.getString(_cacheAtKey) ?? '');
    if (cached != null &&
        cachedAt != null &&
        DateTime.now().toUtc().difference(cachedAt.toUtc()) < _cacheMaxAge) {
      try {
        return _parseStations(jsonDecode(cached) as List);
      } catch (_) {
        await prefs.remove(_cacheKey);
        await prefs.remove(_cacheAtKey);
      }
    }

    final data = await invokeFunction('get-stations');
    final stations = _parseStations(data as List);
    await prefs.setString(_cacheKey, jsonEncode(data));
    await prefs.setString(_cacheAtKey, DateTime.now().toUtc().toIso8601String());
    return stations;
  }

  List<Station> _parseStations(List rows) => rows
      .map((row) => Station.fromJson(row as Map<String, dynamic>))
      .toList();

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
