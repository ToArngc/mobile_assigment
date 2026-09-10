class RideLog {
  final String id;
  final String userId;
  final String stationId;
  final DateTime detectedAt;
  final int? delayMinutes;

  final String? destinationStationId;

  final int? durationMinutes;

  final String? stationName;
  final String? stationLine;
  final String? destinationStationName;

  RideLog({
    required this.id,
    required this.userId,
    required this.stationId,
    required this.detectedAt,
    this.delayMinutes,
    this.destinationStationId,
    this.durationMinutes,
    this.stationName,
    this.stationLine,
    this.destinationStationName,
  });

  factory RideLog.fromJson(Map<String, dynamic> json) {
    final joinedStation = json['stations'] as Map<String, dynamic>?;
    final joinedDestination =
        json['destination_station'] as Map<String, dynamic>?;
    return RideLog(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      stationId: json['station_id'] as String,
      detectedAt: DateTime.parse(json['detected_at'] as String),
      delayMinutes: json['delay_minutes'] as int?,
      destinationStationId: json['destination_station_id'] as String?,
      durationMinutes: json['duration_minutes'] as int?,
      stationName: joinedStation?['name'] as String?,
      stationLine: joinedStation?['line'] as String?,
      destinationStationName: joinedDestination?['name'] as String?,
    );
  }

  bool get hasFullTripDetail => destinationStationId != null;
}
