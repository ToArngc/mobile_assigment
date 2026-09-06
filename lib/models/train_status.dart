class TrainStatus {
  final String id;
  final String stationId;
  final String line;
  final String? tripId;
  final DateTime scheduledTime;
  final DateTime? actualTime;
  final int? delayMinutes;
  final DateTime recordedAt;

  TrainStatus({
    required this.id,
    required this.stationId,
    required this.line,
    this.tripId,
    required this.scheduledTime,
    this.actualTime,
    this.delayMinutes,
    required this.recordedAt,
  });

  factory TrainStatus.fromJson(Map<String, dynamic> json) {
    return TrainStatus(
      id: json['id'] as String,
      stationId: json['station_id'] as String,
      line: json['line'] as String,
      tripId: json['trip_id'] as String?,
      scheduledTime: DateTime.parse(json['scheduled_time'] as String),
      actualTime: json['actual_time'] != null
          ? DateTime.parse(json['actual_time'] as String)
          : null,
      delayMinutes: json['delay_minutes'] as int?,
      recordedAt: DateTime.parse(json['recorded_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'station_id': stationId,
      'line': line,
      'trip_id': tripId,
      'scheduled_time': scheduledTime.toIso8601String(),
      'actual_time': actualTime?.toIso8601String(),
      'delay_minutes': delayMinutes,
      'recorded_at': recordedAt.toIso8601String(),
    };
  }

  bool get isOnTime => (delayMinutes ?? 0) <= 2; // adjust threshold as needed
}