import 'dart:typed_data';

import 'supabase_service.dart';
import '../models/fault_report.dart';

/// The category chips shown on the Report an Issue screen, mapped to the
/// string values stored in fault_reports.issue_type. issue_type has no
/// check constraint in the schema, so all five are safe to submit.
enum ReportCategory {
  liftBroken('Broken lift', 'lift_broken'),
  escalatorBroken('Broken escalator', 'escalator_broken'),
  overcrowding('Overcrowding', 'overcrowding'),
  cleanliness('Cleanliness', 'cleanliness'),
  safetyHazard('Safety hazard', 'safety_hazard');

  final String label;
  final String issueType;
  const ReportCategory(this.label, this.issueType);

  static ReportCategory fromIssueType(String value) {
    return ReportCategory.values.firstWhere(
      (c) => c.issueType == value,
      orElse: () => ReportCategory.overcrowding,
    );
  }
}

class ReportsRepository {
  final _client = SupabaseService.client;

  /// Recent reports for a station, newest first — shown inline on
  /// ReportIssueScreen once a station is selected.
  Future<List<FaultReport>> getRecentReports(String stationId, {int limit = 20}) async {
    try {
      final data = await _client
          .from('fault_reports')
          .select()
          .eq('station_id', stationId)
          .order('created_at', ascending: false)
          .limit(limit);
      return (data as List).map((row) => FaultReport.fromJson(row)).toList();
    } catch (e) {
      throw Exception('Failed to load reports: $e');
    }
  }

  /// All of one rider's own submitted reports, newest first — feeds the
  /// "My reports" list on ReportsHomeScreen.
  Future<List<FaultReport>> getMyReports(String userId, {int limit = 50}) async {
    try {
      final data = await _client
          .from('fault_reports')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);
      return (data as List).map((row) => FaultReport.fromJson(row)).toList();
    } catch (e) {
      throw Exception('Failed to load your reports: $e');
    }
  }

  /// Uploads the photo (if any) to the report-photos storage bucket and
  /// inserts one fault_reports row. The schema stores one issue per row,
  /// so a submission with several categories calls this once per category.
  Future<FaultReport> submitReport({
    required String? userId,
    required String stationId,
    required ReportCategory category,
    String? description,
    Uint8List? photoBytes,
    String? photoFileName,
    double? lat,
    double? lng,
  }) async {
    try {
      String? photoUrl;
      if (photoBytes != null && photoFileName != null) {
        final path = '$stationId/${DateTime.now().millisecondsSinceEpoch}_$photoFileName';
        await _client.storage.from('report-photos').uploadBinary(path, photoBytes);
        photoUrl = _client.storage.from('report-photos').getPublicUrl(path);
      }

      final data = await _client
          .from('fault_reports')
          .insert({
            'user_id': userId,
            'station_id': stationId,
            'issue_type': category.issueType,
            'description': description,
            'photo_url': photoUrl,
            'lat': lat,
            'lng': lng,
            'status': 'open',
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return FaultReport.fromJson(data);
    } catch (e) {
      throw Exception('Failed to submit report: $e');
    }
  }

  /// Lets a rider mark their own report resolved. RLS restricts this to
  /// rows they own — affects zero rows silently otherwise, same caveat
  /// as AlertsRepository.setEnabled.
  Future<void> markResolved(String reportId) async {
    try {
      await _client.from('fault_reports').update({'status': 'resolved'}).eq('id', reportId);
    } catch (e) {
      throw Exception('Failed to update report status: $e');
    }
  }
}
