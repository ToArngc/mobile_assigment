import '../core/malaysia_time.dart';

class MuteSettings {
  final String userId;
  final DateTime? mutedUntil;
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

  bool get isMutedNow {
    if (mutedUntil == null) return false;
    final now = MalaysiaTime.now();
    final endOfMutedDay = DateTime(
      mutedUntil!.year,
      mutedUntil!.month,
      mutedUntil!.day + 1,
    );
    return now.isBefore(endOfMutedDay);
  }
}
