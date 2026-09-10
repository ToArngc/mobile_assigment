class TrainStatus {
  final String id;
  final String stationId;
  final String line;
  final String? tripId;
  final double? lat;
  final double? lng;
  final DateTime scheduledTime;
  final DateTime? actualTime;
  final int? delayMinutes;
  final DateTime recordedAt;

  TrainStatus({
    required this.id,
    required this.stationId,
    required this.line,
    this.tripId,
    this.lat,
    this.lng,
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
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      scheduledTime: DateTime.parse(json['scheduled_time'] as String),
      actualTime: json['actual_time'] != null
          ? DateTime.parse(json['actual_time'] as String)
          : null,
      delayMinutes: json['delay_minutes'] as int?,
      recordedAt: DateTime.parse(json['recorded_at'] as String),
    );
  }

}
