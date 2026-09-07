import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/fault_report.dart';
import 'edge_function_client.dart';

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
  /// Recent reports for a station, newest first — shown inline on
  /// ReportIssueScreen once a station is selected.
  Future<List<FaultReport>> getRecentReports(String stationId, {int limit = 20}) async {
    try {
      final data = await invokeFunction(
        'get-station-reports',
        queryParameters: {'station_id': stationId, 'limit': '$limit'},
      );
      return (data as List)
          .map((row) => FaultReport.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load reports: $e');
    }
  }

  /// All of one rider's own submitted reports, newest first — feeds the
  /// "My reports" list on ReportsHomeScreen. [userId] is kept in the
  /// signature but get-my-reports is JWT-scoped to the caller.
  Future<List<FaultReport>> getMyReports(String userId, {int limit = 50}) async {
    try {
      final data = await invokeFunction(
        'get-my-reports',
        queryParameters: {'limit': '$limit'},
      );
      return (data as List)
          .map((row) => FaultReport.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load your reports: $e');
    }
  }

  /// Submits one fault report as multipart/form-data in a single call —
  /// submit-fault-report uploads the photo (if any) to the report-photos
  /// bucket and inserts the fault_reports row server-side, using its own
  /// service-role client. The schema stores one issue per row, so a
  /// submission with several categories calls this once per category.
  /// [userId] is kept in the signature but the function always forces
  /// user_id to the JWT-authenticated caller.
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
      final fields = <String, String>{
        'station_id': stationId,
        'issue_type': category.issueType,
        if (description != null) 'description': description,
        if (lat != null) 'lat': '$lat',
        if (lng != null) 'lng': '$lng',
      };
      final files = photoBytes != null && photoFileName != null
          ? [MultipartFile.fromBytes('photo', photoBytes, filename: photoFileName)]
          : null;

      final data = await invokeFunction(
        'submit-fault-report',
        method: HttpMethod.post,
        body: fields,
        files: files,
      );
      return FaultReport.fromJson(data as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to submit report: $e');
    }
  }

  /// Lets a rider mark their own report resolved. resolve-fault-report
  /// filters to rows owned by the caller server-side (404 otherwise),
  /// reproducing the same ownership check the old direct UPDATE had.
  Future<void> markResolved(String reportId) async {
    try {
      await invokeFunction(
        'resolve-fault-report',
        method: HttpMethod.patch,
        body: {'id': reportId},
      );
    } catch (e) {
      throw Exception('Failed to update report status: $e');
    }
  }
}
