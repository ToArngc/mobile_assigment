class Station {
  final String id;
  final String name;
  final String line;
  final double lat;
  final double lng;
  final Map<String, dynamic>? accessibilityFeatures;

  Station({
    required this.id,
    required this.name,
    required this.line,
    required this.lat,
    required this.lng,
    this.accessibilityFeatures,
  });

  factory Station.fromJson(Map<String, dynamic> json) => Station(
        id: json['id'] as String,
        name: json['name'] as String,
        line: json['line'] as String,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        accessibilityFeatures:
            json['accessibility_features'] as Map<String, dynamic>?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'line': line,
        'lat': lat,
        'lng': lng,
        'accessibility_features': accessibilityFeatures,
      };

  List<String> get lines => line
      .split(RegExp(r'\s*(?:,|/|\||&| and )\s*', caseSensitive: false))
      .where((value) => value.trim().isNotEmpty)
      .map((value) => value.trim())
      .toList();
}
