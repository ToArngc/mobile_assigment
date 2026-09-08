enum FaultStatus { open, resolved }

class FaultReport {
  final String id;
  final String? userId; // null if user account was deleted
  final String stationId;
  final String issueType; // 'lift_broken' | 'escalator_broken' | 'overcrowding'
  final String? description;
  final String? photoUrl; // Supabase Storage URL
  final double? lat;
  final double? lng;
  final FaultStatus status;
  final DateTime createdAt;

  FaultReport({
    required this.id,
    this.userId,
    required this.stationId,
    required this.issueType,
    this.description,
    this.photoUrl,
    this.lat,
    this.lng,
    this.status = FaultStatus.open,
    required this.createdAt,
  });

  factory FaultReport.fromJson(Map<String, dynamic> json) {
    return FaultReport(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      stationId: json['station_id'] as String,
      issueType: json['issue_type'] as String,
      description: json['description'] as String?,
      photoUrl: json['photo_url'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      status: (json['status'] as String? ?? 'open') == 'resolved'
          ? FaultStatus.resolved
          : FaultStatus.open,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Same report, flipped to resolved — used to reflect a successful
  /// resolve-fault-report call without refetching the list.
  FaultReport copyWithResolved() => FaultReport(
        id: id,
        userId: userId,
        stationId: stationId,
        issueType: issueType,
        description: description,
        photoUrl: photoUrl,
        lat: lat,
        lng: lng,
        status: FaultStatus.resolved,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'station_id': stationId,
      'issue_type': issueType,
      'description': description,
      'photo_url': photoUrl,
      'lat': lat,
      'lng': lng,
      'status': status == FaultStatus.resolved ? 'resolved' : 'open',
      'created_at': createdAt.toIso8601String(),
    };
  }
}