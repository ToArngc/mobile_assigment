class SavedStation {
  final String id;
  final String userId;
  final String stationId;
  final int? alertDelayThreshold; // minutes
  final String? quietHoursStart; // "HH:mm:ss"
  final String? quietHoursEnd;
  final List<String>? activeDays; // e.g. ['Mon', 'Tue', 'Wed']
  final DateTime createdAt;

  SavedStation({
    required this.id,
    required this.userId,
    required this.stationId,
    this.alertDelayThreshold,
    this.quietHoursStart,
    this.quietHoursEnd,
    this.activeDays,
    required this.createdAt,
  });

  factory SavedStation.fromJson(Map<String, dynamic> json) {
    return SavedStation(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      stationId: json['station_id'] as String,
      alertDelayThreshold: json['alert_delay_threshold'] as int?,
      quietHoursStart: json['quiet_hours_start'] as String?,
      quietHoursEnd: json['quiet_hours_end'] as String?,
      activeDays: (json['active_days'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'station_id': stationId,
      'alert_delay_threshold': alertDelayThreshold,
      'quiet_hours_start': quietHoursStart,
      'quiet_hours_end': quietHoursEnd,
      'active_days': activeDays,
      'created_at': createdAt.toIso8601String(),
    };
  }
}