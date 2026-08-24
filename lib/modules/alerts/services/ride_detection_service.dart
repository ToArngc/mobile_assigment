import 'dart:async';
import 'dart:math' as math;
import 'package:location/location.dart';

import '../../../services/auth_service.dart';
import '../../../models/station.dart';
import '../../explore/repositories/station_repository.dart';
import '../repositories/weekly_summary_repository.dart';
import '../../../services/location_service.dart';

class RideDetectionService {
  RideDetectionService({
    StationRepository? stationRepository,
    WeeklySummaryRepository? weeklySummaryRepository,
  })  : _stationRepository = stationRepository ?? StationRepository(),
        _weeklySummaryRepository =
            weeklySummaryRepository ?? WeeklySummaryRepository();

  final StationRepository _stationRepository;
  final WeeklySummaryRepository _weeklySummaryRepository;


  static const double _proximityThresholdMeters = 150;

  static const Duration _maxOpenRideAge = Duration(hours: 3);

  List<Station> _stations = [];
  StreamSubscription<LocationData>? _positionSub;

  String? _currentStationId; // station we're currently "at", if any
  _OpenRide? _openRide;

  bool get isRunning => _positionSub != null;

  Future<void> start() async {
    if (isRunning) return;

    final hasPermission = await LocationService.instance.ensurePermission();
    if (!hasPermission) return;

    _stations = await _stationRepository.getAllStations();

    _positionSub =
        LocationService.instance.positionStream.listen(_onPosition);
  }

  void stop() {
    _positionSub?.cancel();
    _positionSub = null;
  }

  Future<void> _onPosition(LocationData position) async {
    if (position.latitude == null || position.longitude == null) return;
    if (!_isCommuteHour(DateTime.now())) return;
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
      // Left the vicinity of whatever station we were at -- clear the
      // "currently at" marker so arriving back at the *same* station
      // later can trigger detection again instead of being ignored as a
      // no-op.
      _currentStationId = null;
      return;
    }

    if (nearest.id == _currentStationId) return; // still at the same one

    _currentStationId = nearest.id;
    await _handleArrival(nearest, userId);
  }

  Future<void> _handleArrival(Station station, String userId) async {
    final open = _openRide;

    if (open == null || DateTime.now().difference(open.startedAt) > _maxOpenRideAge) {
      // First station seen this session, or the previous open ride is
      // too stale to sensibly pair with this arrival -- start fresh.
      // (The stale one is simply dropped -- nothing was ever written
      // for it, since we only write on completion.)
      _openRide = _OpenRide(
        originStationId: station.id,
        startedAt: DateTime.now(),
      );
      return;
    }

    if (station.id == open.originStationId) {
      // Arrived back at the same station -- not a distinct destination,
      // ignore rather than logging a zero-distance "trip".
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

  /// Haversine great-circle distance in meters. The `location` package
  /// doesn't ship a distance helper the way geolocator did, so this is
  /// spelled out explicitly.
  double _distanceMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadiusMeters = 6371000.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLng = _degToRad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  double _degToRad(double deg) => deg * (math.pi / 180);

  bool _isCommuteHour(DateTime now) {
    final hour = now.hour;
    return (hour >= 7 && hour < 10) || (hour >= 17 && hour < 20);
  }
}

class _OpenRide {
  _OpenRide({
    required this.originStationId,
    required this.startedAt,
  });

  final String originStationId;
  final DateTime startedAt;
}
