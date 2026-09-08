





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


  String get relativeAge {
    final diff = DateTime.now().difference(createdAt.toLocal());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
