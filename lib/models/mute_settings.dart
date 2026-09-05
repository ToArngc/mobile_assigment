
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

  /// `muted_until` is stored as a database DATE. Treat that date as
  /// inclusive, so "mute until Sep 10" remains active through Sep 10.
  bool get isMutedNow {
    if (mutedUntil == null) return false;
    final now = DateTime.now();
    final endOfMutedDay = DateTime(
      mutedUntil!.year,
      mutedUntil!.month,
      mutedUntil!.day + 1,
    );
    return now.isBefore(endOfMutedDay);
  }
}
