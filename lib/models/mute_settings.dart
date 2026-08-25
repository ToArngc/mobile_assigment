
class MuteSettings {
  final String userId;
  final DateTime? mutedUntil; // null = not muted
  final DateTime updatedAt;

  MuteSettings({
    required this.userId,
    this.mutedUntil,
    required this.updatedAt,
  });

  factory MuteSettings.fromJson(Map<String, dynamic> json) {
    return MuteSettings(
      userId: json['user_id'] as String,
      mutedUntil: json['muted_until'] != null
          ? DateTime.parse(json['muted_until'] as String)
          : null,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'muted_until': mutedUntil?.toIso8601String().split('T').first,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get isMutedNow =>
      mutedUntil != null && mutedUntil!.isAfter(DateTime.now());
}