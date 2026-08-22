import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/auth_service.dart';
import '../../../core/models/fault_report.dart';
import '../../../core/models/station.dart';
import '../../../shared/app_palette.dart';
import '../../../shared/app_bottom_nav.dart';
import '../../module1_explorer/repositories/station_repository.dart';
import '../repositories/reports_repository.dart';
import '../widgets/fault_widgets.dart';

class ReportIssueScreen extends StatefulWidget {
  final ReportsRepository reportsRepository;
  final StationRepository stationRepository;

  final Station? initialStation;

  ReportIssueScreen({
    super.key,
    ReportsRepository? reportsRepository,
    StationRepository? stationRepository,
    this.initialStation,
  })  : reportsRepository = reportsRepository ?? ReportsRepository(),
        stationRepository = stationRepository ?? StationRepository();

  @override
  State<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends State<ReportIssueScreen> {
  Station? _selectedStation;
  final Set<ReportCategory> _selectedCategories = {};
  File? _photo;
  bool _submitting = false;
  bool _loadingReports = false;
  List<FaultReport> _recentReports = [];
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _selectedStation = widget.initialStation;
    if (_selectedStation != null) _loadReports();
  }

  Future<void> _loadReports() async {
    final station = _selectedStation;
    if (station == null) return;

    setState(() {
      _loadingReports = true;
      _loadError = null;
    });
    try {
      final reports = await widget.reportsRepository.getRecentReports(station.id);
      if (!mounted) return;
      setState(() {
        _recentReports = reports;
        _loadingReports = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _loadingReports = false;
      });
    }
  }

  bool get _canSubmit => _selectedStation != null && _selectedCategories.isNotEmpty && !_submitting;

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (picked != null) {
      setState(() => _photo = File(picked.path));
    }
  }

  Future<void> _pickStation() async {
    List<Station> stations;
    try {
      stations = await widget.stationRepository.getAllStations();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load stations: $e')),
      );
      return;
    }
    if (!mounted) return;

    final result = await showModalBottomSheet<Station>(
      context: context,
      backgroundColor: AppPalette.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StationPickerSheet(current: _selectedStation, stations: stations),
    );

    if (result != null && result.id != _selectedStation?.id) {
      setState(() => _selectedStation = result);
      _loadReports();
    }
  }

  Future<void> _submitReport() async {
    if (!_canSubmit) return;
    setState(() => _submitting = true);

    try {
      // Only the first selected category maps to issue_type (the schema
      // stores one issue per row). If a rider picks several, submit one
      // report per category so each still shows up as its own card.
      for (final category in _selectedCategories) {
        final newReport = await widget.reportsRepository.submitReport(
          userId: AuthService.currentUserId,
          stationId: _selectedStation!.id,
          category: category,
          photoBytes: _photo != null ? await _photo!.readAsBytes() : null,
          photoFileName: _photo?.uri.pathSegments.last,
        );
        if (!mounted) return;
        setState(() => _recentReports = [newReport, ..._recentReports]);
      }

      if (!mounted) return;
      setState(() {
        _selectedCategories.clear();
        _photo = null;
        _submitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report submitted — thanks for helping other riders'),
          backgroundColor: AppPalette.teal,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submit failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          children: [
            const Text(
              'Report an issue',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppPalette.ink,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Help other commuters stay informed',
              style: TextStyle(fontSize: 14, color: AppPalette.subtext),
            ),
            const SizedBox(height: 24),

            const SectionLabel('STATION'),
            const SizedBox(height: 8),
            StationField(station: _selectedStation, onTap: _pickStation),
            const SizedBox(height: 22),

            const SectionLabel('CATEGORY'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: ReportCategory.values.map((cat) {
                final selected = _selectedCategories.contains(cat);
                return CategoryChip(
                  category: cat,
                  selected: selected,
                  onTap: () => setState(() {
                    selected ? _selectedCategories.remove(cat) : _selectedCategories.add(cat);
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 22),

            const SectionLabel('PHOTO (OPTIONAL)'),
            const SizedBox(height: 10),
            PhotoPicker(photo: _photo, onTap: _pickPhoto, onClear: () => setState(() => _photo = null)),
            const SizedBox(height: 18),

            SubmitButton(enabled: _canSubmit, loading: _submitting, onTap: _submitReport),
            const SizedBox(height: 26),

            SectionLabel(
              _selectedStation == null
                  ? 'RECENT REPORTS'
                  : 'RECENT REPORTS — ${_selectedStation!.name.toUpperCase()}',
            ),
            const SizedBox(height: 10),
            if (_selectedStation == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('Select a station to see its recent reports.',
                      style: TextStyle(color: AppPalette.subtext)),
                ),
              )
            else if (_loadingReports)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator(color: AppPalette.teal)),
              )
            else if (_loadError != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text(_loadError!, style: const TextStyle(color: AppPalette.red))),
              )
            else if (_recentReports.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('No reports yet for this station.', style: TextStyle(color: AppPalette.subtext)),
                ),
              )
            else
              ..._recentReports.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ReportCard(report: r),
                  )),
            const SizedBox(height: 8),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(active: AppTab.reports),
    );
  }
}
