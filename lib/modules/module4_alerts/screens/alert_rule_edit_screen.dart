import 'package:flutter/material.dart';
import '../../../core/models/station.dart';
import '../../../core/models/saved_station.dart';
import '../../../core/auth_service.dart';
import '../repositories/alerts_repository.dart';

/// Step 2 of adding an Alert Rule: set the threshold, quiet hours, and
/// active days for the station chosen in SelectStationScreen.
///
/// Saves directly through AlertsRepository rather than reading
/// AlertsProvider via Provider.of — this screen is pushed onto the root
/// Navigator (above MaterialApp), which sits outside the
/// ChangeNotifierProvider<AlertsProvider> scope declared in
/// AlertsHomeScreen, so Provider.of would fail here.
/// Pops `true` on success; the caller (AlertsHomeScreen) is responsible
/// for calling provider.loadAll() to refresh the list.
class AlertRuleEditScreen extends StatefulWidget {
  final Station station;
  final SavedStation? existing; // non-null when editing an existing rule

  const AlertRuleEditScreen({super.key, required this.station, this.existing});

  @override
  State<AlertRuleEditScreen> createState() => _AlertRuleEditScreenState();
}

class _AlertRuleEditScreenState extends State<AlertRuleEditScreen> {
  final _repository = AlertsRepository();
  bool _saving = false;

  late double _thresholdMinutes;
  TimeOfDay? _quietStart;
  TimeOfDay? _quietEnd;
  final Set<String> _activeDays = {};

  static const _allDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _thresholdMinutes = (existing?.alertDelayThreshold ?? 5).toDouble();
    if (existing?.quietHoursStart != null) {
      _quietStart = _parseTimeOfDay(existing!.quietHoursStart!);
    }
    if (existing?.quietHoursEnd != null) {
      _quietEnd = _parseTimeOfDay(existing!.quietHoursEnd!);
    }
    _activeDays.addAll(existing?.activeDays ?? _allDays);
  }

  TimeOfDay _parseTimeOfDay(String hhmmss) {
    final parts = hhmmss.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _formatTimeOfDay(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: (isStart ? _quietStart : _quietEnd) ?? const TimeOfDay(hour: 22, minute: 0),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _quietStart = picked;
      } else {
        _quietEnd = picked;
      }
    });
  }

  Future<void> _save() async {
    final userId = AuthService.currentUserId;
    if (userId == null) return;

    setState(() => _saving = true);
    try {
      final saved = SavedStation(
        id: widget.existing?.id ?? '', // empty id -> upsert treats as insert
        userId: userId,
        stationId: widget.station.id,
        alertDelayThreshold: _thresholdMinutes.round(),
        quietHoursStart: _quietStart != null ? _formatTimeOfDay(_quietStart!) : null,
        quietHoursEnd: _quietEnd != null ? _formatTimeOfDay(_quietEnd!) : null,
        activeDays: _activeDays.toList(),
        createdAt: widget.existing?.createdAt ?? DateTime.now(),
      );
      await _repository.upsertSavedStation(saved);
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
      appBar: AppBar(title: Text('Alert rule · ${widget.station.name}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Delay threshold', style: Theme.of(context).textTheme.titleMedium),
          const Text(
            'Notify me when this station\'s trains are delayed by more than:',
            style: TextStyle(color: Colors.grey),
          ),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _thresholdMinutes,
                  min: 1,
                  max: 30,
                  divisions: 29,
                  label: '${_thresholdMinutes.round()} min',
                  onChanged: (v) => setState(() => _thresholdMinutes = v),
                ),
              ),
              SizedBox(
                width: 56,
                child: Text('${_thresholdMinutes.round()} min', textAlign: TextAlign.end),
              ),
            ],
          ),
          const Divider(height: 32),
          Text('Quiet hours (optional)', style: Theme.of(context).textTheme.titleMedium),
          const Text(
            'No alerts will be sent during this window.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickTime(true),
                  child: Text(_quietStart == null ? 'Start time' : _quietStart!.format(context)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickTime(false),
                  child: Text(_quietEnd == null ? 'End time' : _quietEnd!.format(context)),
                ),
              ),
              if (_quietStart != null || _quietEnd != null)
                IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: 'Clear quiet hours',
                  onPressed: () => setState(() {
                    _quietStart = null;
                    _quietEnd = null;
                  }),
                ),
            ],
          ),
          const Divider(height: 32),
          Text('Active days', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _allDays.map((day) {
              final selected = _activeDays.contains(day);
              return FilterChip(
                label: Text(day),
                selected: selected,
                onSelected: (value) => setState(() {
                  if (value) {
                    _activeDays.add(day);
                  } else {
                    _activeDays.remove(day);
                  }
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Text('Save alert rule'),
          ),
        ],
      ),
    );
  }
}