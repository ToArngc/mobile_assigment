/// One row of the station_accessibility view (design doc §4.1) — the most
/// recent fault report for a given station and issue type.
///
/// This replaces the dropped per-station features column on `stations`. A
/// station with no rows has no reported problems, which is a good state
/// and not an error.
class StationAccessibility {
  final String issueType;
  final String status;
  final DateTime createdAt;

  StationAccessibility({
    required this.issueType,
    required this.status,
    required this.createdAt,
  });

  factory StationAccessibility.fromJson(Map<String, dynamic> json) {
    return StationAccessibility(
      issueType: json['issue_type'] as String,
      status: json['status'] as String? ?? 'open',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  bool get isOpen => status != 'resolved';

  /// How long ago the report was filed, for the "reported 3h ago" label.
  String get relativeAge {
    final diff = DateTime.now().difference(createdAt.toLocal());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
