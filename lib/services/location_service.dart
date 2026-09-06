import 'dart:async';
import 'package:location/location.dart';

/// Thin wrapper around the `location` package, intended to be the *one*
/// place in the app that talks to device location.
///
/// PROPOSAL: Module 1 (live map / station explorer) also needs device
/// position (per the design doc's package table). Rather than Module 1
/// and Module 4 each requesting permission and opening their own location
/// stream, both should consume this single broadcast stream -- avoids
/// duplicate permission prompts and duplicate battery drain from two GPS
/// subscriptions. Confirm with whoever owns Module 1 before wiring either
/// side in.
class LocationService {
  LocationService._internal();
  static final LocationService instance = LocationService._internal();

  final Location _location = Location();
  Stream<LocationData>? _positionStream;
  bool _configured = false;

  /// Requests location service + permission if not already granted.
  /// Returns true if both are available, false otherwise -- callers
  /// should handle the false case gracefully (e.g. ride detection simply
  /// doesn't run) rather than repeatedly prompting.
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

  /// Broadcast stream of position updates. Safe to listen to from
  /// multiple places (e.g. Module 1's map AND Module 4's ride detection)
  /// -- settings are only configured once.
  ///
  /// `distanceFilter` of 25m avoids flooding updates while stationary or
  /// moving slowly, which matters for battery on a background-ish
  /// feature like ride detection. Tighten this if Module 1's map needs
  /// smoother live tracking -- may be worth splitting into two
  /// differently-tuned streams instead of one shared one if those
  /// requirements conflict; team decision.
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
