class RideLog {
  final String id;
  final String userId;
  final String stationId;
  final DateTime detectedAt;
  final int? delayMinutes;

  /// Station the ride ended at. Null if the ride was never "closed out"
  /// (app closed, commute window ended, etc before a second station was
  /// detected) -- see the ride detection design note.
  final String? destinationStationId;

  /// Minutes between [detectedAt] and the destination detection.
  /// Null until [destinationStationId] is set.
  final int? durationMinutes;

  // Populated only when fetched with a joined `stations` select — not a
  // real column on ride_logs.
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'station_id': stationId,
      'detected_at': detectedAt.toIso8601String(),
      'delay_minutes': delayMinutes,
      'destination_station_id': destinationStationId,
      'duration_minutes': durationMinutes,
    };
  }

  /// True once the ride has an origin and a destination -- i.e. the
  /// mockup's full "origin → destination, Xmin" row can be shown.
  bool get hasFullTripDetail => destinationStationId != null;
}
