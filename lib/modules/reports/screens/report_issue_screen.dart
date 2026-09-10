import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/friendly_error.dart';
import '../../../core/theme.dart';
import '../../../models/fault_report.dart';
import '../../../models/station.dart';
import '../../../services/auth_service.dart';
import '../../../services/location_service.dart';
import '../../../services/reports_repository.dart';
import '../../../services/station_repository.dart';
import '../widgets/report_card.dart';
import 'pick_report_station_screen.dart';

class ReportIssueScreen extends StatefulWidget {
  const ReportIssueScreen({super.key});

  @override
  State<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends State<ReportIssueScreen> {
  final _repository = ReportsRepository();
  final _stationRepository = StationRepository();

  final _descriptionController = TextEditingController();

  Station? _station;
  final Set<ReportCategory> _categories = {};
  File? _photo;
  double? _lat;
  double? _lng;

  static const double _proximityThresholdMeters = 150;

  bool _locating = false;
  bool _saving = false;
  Future<List<FaultReport>>? _recentReportsFuture;

  @override
  void initState() {
    super.initState();
    _detectNearestStation();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _detectNearestStation() async {
    setState(() => _locating = true);
    try {
      final hasPermission = await LocationService.instance.ensurePermission();
      if (!hasPermission) return;

      final position =
          await LocationService.instance.positionStream.first.timeout(const Duration(seconds: 8));
      if (position.latitude == null || position.longitude == null) return;

      final stations = await _stationRepository.getAllStations();
      final nearest = _nearestStation(stations, position.latitude!, position.longitude!);
      if (nearest != null && mounted) {
        setState(() {
          _station = nearest;
          _lat = position.latitude;
          _lng = position.longitude;
        });
        _loadRecentReports();
      }
    } catch (_) {


    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Station? _nearestStation(List<Station> stations, double lat, double lng) {
    if (stations.isEmpty) return null;
    Station best = stations.first;
    double bestDist = _distanceMeters(lat, lng, best.lat, best.lng);
    for (final s in stations.skip(1)) {
      final d = _distanceMeters(lat, lng, s.lat, s.lng);
      if (d < bestDist) {
        best = s;
        bestDist = d;
      }
    }
    return bestDist > _proximityThresholdMeters ? null : best;
  }

  double _distanceMeters(double lat1, double lng1, double lat2, double lng2) {
    const earthRadius = 6371000.0;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) * math.cos(_toRad(lat2)) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _toRad(double deg) => deg * (math.pi / 180);

  void _loadRecentReports() {
    final station = _station;
    if (station == null) return;
    setState(() => _recentReportsFuture = _repository.getRecentReports(station.id));
  }

  Future<void> _pickStation() async {
    final result = await Navigator.of(context).push<Station>(
      MaterialPageRoute(builder: (_) => const PickReportStationScreen()),
    );
    if (result != null) {
      setState(() {
        _station = result;

        _lat = null;
        _lng = null;
      });
      _loadRecentReports();
    }
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1600,
      );
      if (picked != null) setState(() => _photo = File(picked.path));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open that source. Check the app permission and try again.',
          ),
        ),
      );
    }
  }

  bool get _canSave => _station != null && _categories.isNotEmpty && !_saving;

  Future<void> _submit() async {
    final userId = AuthService.currentUserId;
    if (!_canSave || userId == null) return;

    setState(() => _saving = true);
    try {
      Uint8List? photoBytes;
      String? photoFileName;
      if (_photo != null) {
        photoBytes = await _photo!.readAsBytes();
        photoFileName = _photo!.uri.pathSegments.last;
      }

      final description = _descriptionController.text.trim();
      await _repository.submitReport(
        userId: userId,
        stationId: _station!.id,
        categories: _categories.toList(),
        description: description.isEmpty ? null : description,
        photoBytes: photoBytes,
        photoFileName: photoFileName,
        lat: _lat,
        lng: _lng,
      );

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              friendlyErrorMessage(
                e,
                fallback: 'We couldn\'t submit your report. Please try again.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report an issue')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Station', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ListTile(
            shape: RoundedRectangleBorder(
              side: BorderSide(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            leading: const Icon(Icons.location_on_outlined),
            title: Text(_station?.name ?? 'Select a station'),
            subtitle: _locating
                ? const Text('Finding your nearest station…')
                : (_station != null ? Text(_station!.line) : null),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickStation,
          ),
          const Divider(height: 32),

          Text('Category', style: Theme.of(context).textTheme.titleMedium),
          const Text(
            "What's wrong?",
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ReportCategory.values.map((cat) {
              final selected = _categories.contains(cat);
              return FilterChip(
                label: Text(cat.label),
                selected: selected,
                onSelected: (value) => setState(() {
                  value ? _categories.add(cat) : _categories.remove(cat);
                }),
              );
            }).toList(),
          ),
          const Divider(height: 32),

          Text('Description (optional)', style: Theme.of(context).textTheme.titleMedium),
          const Text(
            'Anything else that would help staff find the problem?',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descriptionController,
            maxLines: 3,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'What is wrong, and where exactly?',
            ),
          ),
          const Divider(height: 32),

          Text('Photo (optional)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_photo != null)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(_photo!, height: 160, width: double.infinity, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton.filled(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _photo = null),
                  ),
                ),
              ],
            )
          else
            OutlinedButton.icon(
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Add a photo'),
              onPressed: _pickPhoto,
            ),
          const SizedBox(height: 24),

          FilledButton(
            onPressed: _canSave ? _submit : null,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Submit report'),
          ),

          if (_station != null) ...[
            const Divider(height: 40),
            Text('Recent reports — ${_station!.name}', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            FutureBuilder<List<FaultReport>>(
              future: _recentReportsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Text(
                    friendlyErrorMessage(
                      snapshot.error,
                      fallback: 'Recent reports could not be loaded.',
                    ),
                    style: const TextStyle(color: AppColors.danger),
                  );
                }
                final reports = snapshot.data ?? [];
                if (reports.isEmpty) {
                  return const Text(
                    'No reports yet for this station.',
                    style: TextStyle(color: AppColors.textSecondary),
                  );
                }
                return Column(children: reports.map((r) => ReportCard(report: r)).toList());
              },
            ),
          ],
        ],
      ),
    );
  }
}
