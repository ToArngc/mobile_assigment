class SavedStation {
  final String id;
  final String userId;
  final String stationId;
  final int? alertDelayThreshold; // minutes
  final String? quietHoursStart; // "HH:mm:ss"
  final String? quietHoursEnd;
  final List<String>? activeDays; // e.g. ['Mon', 'Tue', 'Wed']
  final bool enabled;
  final DateTime createdAt;

  // Populated only when the repository fetches with a joined `stations`
  // select (see AlertsRepository.getSavedStations) — not a real column on
  // saved_stations, so never sent back in toJson().
  final String? stationName;
  final String? stationLine;

  SavedStation({
    required this.id,
    required this.userId,
    required this.stationId,
    this.alertDelayThreshold,
    this.quietHoursStart,
    this.quietHoursEnd,
    this.activeDays,
    this.enabled = true,
    required this.createdAt,
    this.stationName,
    this.stationLine,
  });

  factory SavedStation.fromJson(Map<String, dynamic> json) {
    // When fetched with `.select('*, stations(name, line)')`, Supabase
    // nests the joined row under the 'stations' key.
    final joinedStation = json['stations'] as Map<String, dynamic>?;

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
      enabled: json['enabled'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      stationName: joinedStation?['name'] as String?,
      stationLine: joinedStation?['line'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final json = {
      'id': id,
      'user_id': userId,
      'station_id': stationId,
      'alert_delay_threshold': alertDelayThreshold,
      'quiet_hours_start': quietHoursStart,
      'quiet_hours_end': quietHoursEnd,
      'active_days': activeDays,
      'enabled': enabled,
      'created_at': createdAt.toIso8601String(),
    };
    if (id.isEmpty) json.remove('id');
    return json;
  }

  SavedStation copyWith({bool? enabled}) {
    return SavedStation(
      id: id,
      userId: userId,
      stationId: stationId,
      alertDelayThreshold: alertDelayThreshold,
      quietHoursStart: quietHoursStart,
      quietHoursEnd: quietHoursEnd,
      activeDays: activeDays,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt,
      stationName: stationName,
      stationLine: stationLine,
    );
  }
}