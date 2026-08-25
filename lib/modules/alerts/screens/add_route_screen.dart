import 'package:flutter/material.dart';
import '../../../models/station.dart';
import '../../../models/saved_route.dart';
import '../../../services/auth_service.dart';
import '../../../services/leave_by_repository.dart';
import 'pick_station_screen.dart';

/// Pushed on the root Navigator, same pattern as AlertRuleEditScreen —
/// saves directly via LeaveByRepository (no Provider.of) and pops `true`
/// on success so the caller can refresh.
class AddRouteScreen extends StatefulWidget {
  const AddRouteScreen({super.key});

  @override
  State<AddRouteScreen> createState() => _AddRouteScreenState();
}

class _AddRouteScreenState extends State<AddRouteScreen> {
  final _repository = LeaveByRepository();
  Station? _origin;
  Station? _destination;
  int _walkingMinutes = 10;
  bool _saving = false;

  Future<void> _pickOrigin() async {
    final station = await Navigator.of(context).push<Station>(
      MaterialPageRoute(
        builder: (_) => const PickStationScreen(title: 'From (origin)'),
      ),
    );
    if (station != null) setState(() => _origin = station);
  }

  Future<void> _pickDestination() async {
    final station = await Navigator.of(context).push<Station>(
      MaterialPageRoute(
        builder: (_) => const PickStationScreen(title: 'To (destination)'),
      ),
    );
    if (station != null) setState(() => _destination = station);
  }

  bool get _canSave => _origin != null && _destination != null && !_saving;

  Future<void> _save() async {
    final userId = AuthService.currentUserId;
    if (userId == null || _origin == null || _destination == null) return;

    setState(() => _saving = true);
    try {
      await _repository.upsertSavedRoute(SavedRoute(
        id: '',
        userId: userId,
        originStationId: _origin!.id,
        destinationStationId: _destination!.id,
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
            leading: const Icon(Icons.trip_origin),
            title: Text(_origin?.name ?? 'Choose origin station'),
            onTap: _pickOrigin,
          ),
          const SizedBox(height: 12),
          ListTile(
            shape: RoundedRectangleBorder(
              side: BorderSide(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            leading: const Icon(Icons.flag),
            title: Text(_destination?.name ?? 'Choose destination station'),
            onTap: _pickDestination,
          ),
          const Divider(height: 32),
          Text('Walking time to station', style: Theme.of(context).textTheme.titleMedium),
          const Text(
            'How long does it take you to walk from home to the origin station?',
            style: TextStyle(color: Colors.grey),
          ),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _walkingMinutes.toDouble(),
                  min: 1,
                  max: 60,
                  divisions: 59,
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
}