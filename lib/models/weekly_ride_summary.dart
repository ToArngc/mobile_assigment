









class WeeklyRideSummary {
  final int rideCount;
  final int onTimeCount;
  final double? onTimePercentage;
  final double? averageDelayMinutes;
  final List<WeeklyRide> rides;

  WeeklyRideSummary({
    required this.rideCount,
    required this.onTimeCount,
    this.onTimePercentage,
    this.averageDelayMinutes,
    this.rides = const [],
  });

  factory WeeklyRideSummary.fromJson(Map<String, dynamic> json) {
    final rides = json['rides'] as List? ?? const [];
    return WeeklyRideSummary(
      rideCount: (json['ride_count'] as num?)?.toInt() ?? 0,
      onTimeCount: (json['on_time_count'] as num?)?.toInt() ?? 0,
      onTimePercentage: (json['on_time_percentage'] as num?)?.toDouble(),
      averageDelayMinutes: (json['avg_delay_minutes'] as num?)?.toDouble(),
      rides: rides
          .map((row) => WeeklyRide.fromJson(row as Map<String, dynamic>))
          .toList(),
    );
  }



  bool get hasDelayData => onTimePercentage != null;

  static WeeklyRideSummary empty() =>
      WeeklyRideSummary(rideCount: 0, onTimeCount: 0);
}

class WeeklyRide {
  final String? stationName;
  final DateTime detectedAt;
  final int? delayMinutes;

  WeeklyRide({
    this.stationName,
    required this.detectedAt,
    this.delayMinutes,
  });

  factory WeeklyRide.fromJson(Map<String, dynamic> json) {
    return WeeklyRide(
      stationName: json['station_name'] as String?,
      detectedAt: DateTime.parse(json['detected_at'] as String),
      delayMinutes: (json['delay_minutes'] as num?)?.toInt(),
    );
  }
}
