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
    final parsedRides = rides
        .map((row) => WeeklyRide.fromJson(row as Map<String, dynamic>))
        .toList();
    final delayedRides = parsedRides
        .map((ride) => ride.delayMinutes)
        .whereType<int>()
        .where((delay) => delay > 0)
        .toList();
    final calculatedAverageDelay = delayedRides.isEmpty
        ? null
        : delayedRides.reduce((sum, delay) => sum + delay) /
            delayedRides.length;

    return WeeklyRideSummary(
      rideCount: (json['ride_count'] as num?)?.toInt() ?? 0,
      onTimeCount: (json['on_time_count'] as num?)?.toInt() ?? 0,
      onTimePercentage: (json['on_time_percentage'] as num?)?.toDouble(),
      // Average delay means the average of late trains. Early arrivals do not
      // offset real delays in the value the commuter sees.
      averageDelayMinutes: calculatedAverageDelay ??
          (json['avg_delay_minutes'] as num?)?.toDouble(),
      rides: parsedRides,
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
