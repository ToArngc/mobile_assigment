class SavedRoute {
  final String id;
  final String userId;
  final String originStationId;
  final String? destinationStationId;
  final int walkingMinutes;
  final DateTime createdAt;
  final String? stationName;
  final String? stationLine;

  SavedRoute({
    required this.id,
    required this.userId,
    required this.originStationId,
    this.destinationStationId,
    this.walkingMinutes = 10,
    required this.createdAt,
    this.stationName,
    this.stationLine,
  });

  factory SavedRoute.fromJson(Map<String, dynamic> json) {
    return SavedRoute(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      originStationId: json['origin_station_id'] as String,
      destinationStationId: json['destination_station_id'] as String?,
      walkingMinutes: json['walking_minutes'] as int? ?? 10,
      createdAt: DateTime.parse(json['created_at'] as String),
      stationName: (json['origin_station'] as Map?)?['name'] as String?,
      stationLine: (json['origin_station'] as Map?)?['line'] as String?,
    );
  }

  static SavedRoute? tryFromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final userId = json['user_id'];
    final originStationId = json['origin_station_id'];
    final createdAt = DateTime.tryParse(json['created_at']?.toString() ?? '');

    if (id is! String ||
        userId is! String ||
        originStationId is! String ||
        createdAt == null) {
      return null;
    }

    return SavedRoute(
      id: id,
      userId: userId,
      originStationId: originStationId,
      destinationStationId: json['destination_station_id'] as String?,
      walkingMinutes: (json['walking_minutes'] as num?)?.toInt() ?? 10,
      createdAt: createdAt,
      stationName: (json['origin_station'] as Map?)?['name'] as String?,
      stationLine: (json['origin_station'] as Map?)?['line'] as String?,
    );
  }

}
