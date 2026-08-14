class RideLog {
  final String id;
  final String userId;
  final String stationId;
  final DateTime detectedAt;
  final int? delayMinutes;

  RideLog({
    required this.id,
    required this.userId,
    required this.stationId,
    required this.detectedAt,
    this.delayMinutes,
  });

  factory RideLog.fromJson(Map<String, dynamic> json) {
    return RideLog(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      stationId: json['station_id'] as String,
      detectedAt: DateTime.parse(json['detected_at'] as String),
      delayMinutes: json['delay_minutes'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'station_id': stationId,
      'detected_at': detectedAt.toIso8601String(),
      'delay_minutes': delayMinutes,
    };
  }
}