class TimetableEntry {
  final String id;
  final String stationId;
  final String line;
  final String scheduledTime; // Postgres 'time' comes back as "HH:mm:ss"
  final String direction;

  TimetableEntry({
    required this.id,
    required this.stationId,
    required this.line,
    required this.scheduledTime,
    required this.direction,
  });

  factory TimetableEntry.fromJson(Map<String, dynamic> json) {
    return TimetableEntry(
      id: json['id'] as String,
      stationId: json['station_id'] as String,
      line: json['line'] as String,
      scheduledTime: json['scheduled_time'] as String,
      direction: json['direction'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'station_id': stationId,
      'line': line,
      'scheduled_time': scheduledTime,
      'direction': direction,
    };
  }
}