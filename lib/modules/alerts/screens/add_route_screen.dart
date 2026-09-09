import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:location/location.dart';

import '../../../core/theme.dart';
import '../../../models/station.dart';
import '../../../models/saved_route.dart';
import '../../../services/auth_service.dart';
import '../../../services/leave_by_repository.dart';
import '../../../services/location_service.dart';
import 'pick_station_screen.dart';




class AddRouteScreen extends StatefulWidget {
  const AddRouteScreen({super.key});

  @override
  State<AddRouteScreen> createState() => _AddRouteScreenState();
}

class _AddRouteScreenState extends State<AddRouteScreen> {
  final _repository = LeaveByRepository();
  Station? _station;
  int _walkingMinutes = 10;
  bool _saving = false;
  String _locationMessage = 'Choose a station to estimate your walk.';

  Future<void> _pickStation() async {
    final station = await Navigator.of(context).push<Station>(
      MaterialPageRoute(
        builder: (_) => const PickStationScreen(title: 'Choose target station'),
      ),
    );
    if (station == null) return;
    setState(() => _station = station);
    await _estimateWalkingTime(station);
  }

  Future<void> _estimateWalkingTime(Station station) async {
    setState(() {
      _locationMessage = 'Getting your current location…';
    });
    LocationData? location;
    try {
      location = await LocationService.instance
          .getCurrentLocation()
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // The emulator can keep a GPS request pending. The user can still set a
      // walking time manually while location is unavailable.
    }
    if (!mounted) return;
    if (location?.latitude == null || location?.longitude == null) {
      setState(() {
        _locationMessage = 'Location unavailable. Set your walking time below.';
      });
      return;
    }

    final meters = _distanceMeters(
      location!.latitude!,
      location.longitude!,
      station.lat,
      station.lng,
    );
    setState(() {
      _walkingMinutes = (meters / 75).ceil().clamp(1, 120).toInt();
      _locationMessage =
          'Using your current location · ${(meters / 1000).toStringAsFixed(1)} km away';
    });
  }

  bool get _canSave => _station != null && !_saving;

  Future<void> _save() async {
    final userId = AuthService.currentUserId;
    if (userId == null || _station == null) return;

    setState(() => _saving = true);
    try {
      await _repository.upsertSavedRoute(SavedRoute(
        id: '',
        userId: userId,
        originStationId: _station!.id,
        walkingMinutes: _walkingMinutes,
        createdAt: DateTime.now(),
      ));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add a route')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            shape: RoundedRectangleBorder(
              side: BorderSide(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            leading: const Icon(Icons.train_outlined),
            title: Text(_station?.name ?? 'Choose target station'),
            subtitle: const Text('The station you want to catch a train from'),
            onTap: _pickStation,
          ),
          const Divider(height: 32),
          Text('From your current location', style: Theme.of(context).textTheme.titleMedium),
          Text(
            _locationMessage,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _walkingMinutes.toDouble(),
                  min: 1,
                  max: 120,
                  divisions: 119,
                  label: '$_walkingMinutes min',
                  onChanged: (v) => setState(() => _walkingMinutes = v.round()),
                ),
              ),
              SizedBox(width: 56, child: Text('$_walkingMinutes min', textAlign: TextAlign.end)),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _canSave ? _save : null,
            child: _saving
                ? const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Text('Save route'),
          ),
        ],
      ),
    );
  }

  double _distanceMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadiusMeters = 6371000.0;
    final dLat = _radians(lat2 - lat1);
    final dLng = _radians(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_radians(lat1)) *
            math.cos(_radians(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earthRadiusMeters * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _radians(double degrees) => degrees * math.pi / 180;
}
