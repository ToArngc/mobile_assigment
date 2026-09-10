import 'dart:typed_data';

import 'package:http_parser/http_parser.dart';
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

  static ReportCategory? fromIssueType(String value) {
    for (final category in ReportCategory.values) {
      if (category.issueType == value) return category;
    }
    return null;
  }
}

/// The Content-Type of the `photo` part of a submit-fault-report request.
///
/// `MultipartFile.fromBytes` defaults to `application/octet-stream`, which the
/// Edge Function rejects — it validates the part's declared type against
/// image/jpeg, image/png and image/webp. The bytes are the source of truth
/// here because `image_picker` keeps the original file extension when it
/// re-encodes a picked image. Returning null for anything unrecognised leaves
/// the rejection to the server, where it belongs.
MediaType? _photoMediaType(Uint8List bytes) {
  bool startsWith(List<int> signature, {int offset = 0}) {
    if (bytes.length < offset + signature.length) return false;
    for (var i = 0; i < signature.length; i++) {
      if (bytes[offset + i] != signature[i]) return false;
    }
    return true;
  }

  if (startsWith([0xFF, 0xD8, 0xFF])) return MediaType('image', 'jpeg');
  if (startsWith([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
    return MediaType('image', 'png');
  }
  if (startsWith([0x52, 0x49, 0x46, 0x46]) &&
      startsWith([0x57, 0x45, 0x42, 0x50], offset: 8)) {
    return MediaType('image', 'webp');
  }
  return null;
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
      };
      if (description != null) fields['description'] = description;
      if (lat != null) fields['lat'] = '$lat';
      if (lng != null) fields['lng'] = '$lng';
      final files = photoBytes != null && photoFileName != null
          ? [
              MultipartFile.fromBytes(
                'photo',
                photoBytes,
                filename: photoFileName,
                contentType: _photoMediaType(photoBytes),
              )
            ]
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
