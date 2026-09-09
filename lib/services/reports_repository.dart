import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/fault_report.dart';
import 'edge_function_client.dart';




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








  Future<List<FaultReport>> submitReport({
    required String? userId,
    required String stationId,
    required List<ReportCategory> categories,
    String? description,
    Uint8List? photoBytes,
    String? photoFileName,
    double? lat,
    double? lng,
  }) async {
    try {
      final fields = <String, String>{
        'station_id': stationId,
        'issue_type': categories.map((c) => c.issueType).join(','),
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
      return (data as List)
          .map((row) => FaultReport.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to submit report: $e');
    }
  }




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
