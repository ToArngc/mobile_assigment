class SavedRoute {
  final String id;
  final String userId;
  final String originStationId;
  final String destinationStationId;
  final int walkingMinutes;
  final DateTime createdAt;

  SavedRoute({
    required this.id,
    required this.userId,
    required this.originStationId,
    required this.destinationStationId,
    this.walkingMinutes = 10,
    required this.createdAt,
  });

  factory SavedRoute.fromJson(Map<String, dynamic> json) {
    return SavedRoute(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      originStationId: json['origin_station_id'] as String,
      destinationStationId: json['destination_station_id'] as String,
      walkingMinutes: json['walking_minutes'] as int? ?? 10,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    final json = {
      'id': id,
      'user_id': userId,
      'origin_station_id': originStationId,
      'destination_station_id': destinationStationId,
      'walking_minutes': walkingMinutes,
      'created_at': createdAt.toIso8601String(),
    };
    if (id.isEmpty) json.remove('id');
    return json;
  }
}