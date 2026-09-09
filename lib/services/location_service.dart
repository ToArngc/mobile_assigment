import 'dart:async';
import 'package:location/location.dart';











class LocationService {
  LocationService._internal();
  static final LocationService instance = LocationService._internal();

  final Location _location = Location();
  Stream<LocationData>? _positionStream;
  bool _configured = false;





  Future<bool> ensurePermission() async {
    var serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return false;
    }

    var permission = await _location.hasPermission();
    if (permission == PermissionStatus.denied) {
      permission = await _location.requestPermission();
    }
    if (permission == PermissionStatus.deniedForever) return false;

    return permission == PermissionStatus.granted ||
        permission == PermissionStatus.grantedLimited;
  }

  Future<LocationData?> getCurrentLocation() async {
    if (!await ensurePermission()) return null;
    return _location.getLocation();
  }











  Stream<LocationData> get positionStream {
    if (!_configured) {
      _location.changeSettings(
        accuracy: LocationAccuracy.balanced,
        distanceFilter: 25,
      );
      _configured = true;
    }
    _positionStream ??= _location.onLocationChanged.asBroadcastStream();
    return _positionStream!;
  }
}
