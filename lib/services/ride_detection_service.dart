import 'dart:async';
import 'dart:math' as math;
import 'package:location/location.dart';

import '../core/malaysia_time.dart';
import 'auth_service.dart';
import '../models/station.dart';
import 'station_repository.dart';
import 'weekly_summary_repository.dart';
import 'location_service.dart';

class RideDetectionService {
  final StationRepository _stationRepository = StationRepository();
  final WeeklySummaryRepository _weeklySummaryRepository =
      WeeklySummaryRepository();

  static const double _proximityThresholdMeters = 150;

  static const Duration _maxOpenRideAge = Duration(hours: 3);

  List<Station> _stations = [];
  StreamSubscription<LocationData>? _positionSub;

  String? _currentStationId;
  _OpenRide? _openRide;

  bool get isRunning => _positionSub != null;

  Future<void> start() async {
    if (isRunning) return;

    final hasPermission = await LocationService.instance.ensurePermission();
    if (!hasPermission) return;

    _stations = await _stationRepository.getAllStations();

    _positionSub = LocationService.instance.positionStream.listen(_onPosition);
  }

  void stop() {
    _positionSub?.cancel();
    _positionSub = null;
  }

  Future<void> _onPosition(LocationData position) async {
    if (position.latitude == null || position.longitude == null) return;
    if (!MalaysiaTime.isCommuteWindow(MalaysiaTime.now())) return;
    if (_stations.isEmpty) return;

    final userId = AuthService.currentUserId;
    if (userId == null) return;

    final nearest = _nearestStationWithin(
      position.latitude!,
      position.longitude!,
      _stations,
      _proximityThresholdMeters,
    );

    if (nearest == null) {
      _currentStationId = null;
      return;
    }

    if (nearest.id == _currentStationId) return;

    _currentStationId = nearest.id;
    await _handleArrival(nearest, userId);
  }

  Future<void> _handleArrival(Station station, String userId) async {
    final open = _openRide;

    if (open == null ||
        DateTime.now().difference(open.startedAt) > _maxOpenRideAge) {
      _openRide = _OpenRide(
        originStationId: station.id,
        startedAt: DateTime.now(),
      );
      return;
    }

    if (station.id == open.originStationId) {
      return;
    }

    final duration = DateTime.now().difference(open.startedAt).inMinutes;
    await _weeklySummaryRepository.logRide(
      userId: userId,
      stationId: open.originStationId,
      destinationStationId: station.id,
      durationMinutes: duration,
    );
    _openRide = null;
  }

  Station? _nearestStationWithin(
    double lat,
    double lng,
    List<Station> stations,
    double thresholdMeters,
  ) {
    Station? best;
    double bestDistance = double.infinity;

    for (final station in stations) {
      final distance = _distanceMeters(lat, lng, station.lat, station.lng);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = station;
      }
    }

    return (best != null && bestDistance <= thresholdMeters) ? best : null;
  }

  double _distanceMeters(double lat1, double lng1, double lat2, double lng2) {
    const earthRadiusMeters = 6371000.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLng = _degToRad(lng2 - lng1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  double _degToRad(double deg) => deg * (math.pi / 180);
}

class _OpenRide {
  _OpenRide({required this.originStationId, required this.startedAt});

  final String originStationId;
  final DateTime startedAt;
}
