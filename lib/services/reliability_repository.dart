import '../models/train_status.dart';
import 'edge_function_client.dart';

class DailyOnTimeStat {
  final DateTime date;
  final int onTimeCount;
  final int totalCount;

  DailyOnTimeStat({
    required this.date,
    required this.onTimeCount,
    required this.totalCount,
  });

  double get onTimePercent => totalCount == 0 ? 0 : onTimeCount / totalCount * 100;
}

class ReliabilityStatsSummary {
  final int daysOfData;
  final double? onTimePercentage;
  final double? averageDelayMinutes;
  final bool insufficientData;

  ReliabilityStatsSummary({
    required this.daysOfData,
    this.onTimePercentage,
    this.averageDelayMinutes,
    required this.insufficientData,
  });
}

enum RouteReliabilityStatus { onTrack, delayed, unreliable, notEnoughData }

class RouteSuggestion {
  final String originStationName;
  final String originLine;
  final String destinationStationName;
  final int daysOfData;
  final double? weeklyOnTimePercent;
  final RouteReliabilityStatus status;
  final String? alternateLine;
  final double? alternateLineOnTimePercent;

  RouteSuggestion({
    required this.originStationName,
    required this.originLine,
    required this.destinationStationName,
    required this.daysOfData,
    this.weeklyOnTimePercent,
    required this.status,
    this.alternateLine,
    this.alternateLineOnTimePercent,
  });

  factory RouteSuggestion.fromJson(Map<String, dynamic> json) {
    final alternative = json['suggested_alternative'] as Map<String, dynamic>?;
    return RouteSuggestion(
      originStationName: json['origin_station_name'] as String? ?? 'Unknown station',
      originLine: json['origin_line'] as String? ?? '',
      destinationStationName:
          json['destination_station_name'] as String? ?? 'Unknown station',
      daysOfData: json['days_of_data'] as int? ?? 0,
      weeklyOnTimePercent: (json['weekly_on_time_percentage'] as num?)?.toDouble(),
      status: _statusFromString(json['status'] as String?),
      alternateLine: alternative?['line'] as String?,
      alternateLineOnTimePercent:
          (alternative?['on_time_percentage'] as num?)?.toDouble(),
    );
  }

  static RouteReliabilityStatus _statusFromString(String? value) {
    switch (value) {
      case 'delayed':
        return RouteReliabilityStatus.delayed;
      case 'unreliable':
        return RouteReliabilityStatus.unreliable;
      case 'on_track':
        return RouteReliabilityStatus.onTrack;
      case 'not_enough_data':
      default:
        return RouteReliabilityStatus.notEnoughData;
    }
  }
}

class ReliabilityRepository {

  Future<ReliabilityStatsSummary> fetchReliabilitySummary({
    String? lineId,
    String? stationId,
    required int days,
  }) async {
    try {
      final data = await invokeFunction(
        lineId == null && stationId == null
            ? 'get-network-reliability-stats'
            : 'get-reliability-stats',
        queryParameters: {
          if (stationId != null) 'station_id': stationId,
          if (lineId != null) 'line': lineId,
          'days': '$days',
        },
      );
      final map = data as Map<String, dynamic>;
      return ReliabilityStatsSummary(
        daysOfData: map['days_of_data'] as int? ?? 0,
        onTimePercentage: (map['on_time_percentage'] as num?)?.toDouble(),
        averageDelayMinutes: (map['average_delay_minutes'] as num?)?.toDouble(),
        insufficientData: map['insufficient_data'] as bool? ?? true,
      );
    } catch (e) {
      throw Exception('Failed to load data availability: $e');
    }
  }

  Future<List<DailyOnTimeStat>> fetchOnTimeStats({
    String? lineId,
    String? stationId,
    required int days,
  }) async {
    try {
      final data = await invokeFunction(
        'get-reliability-trend',
        queryParameters: {
          if (stationId != null) 'station_id': stationId,
          if (lineId != null) 'line': lineId,
          'days': '$days',
        },
      );

      return (data as List).map((row) {
        final map = row as Map<String, dynamic>;
        return DailyOnTimeStat(
          date: DateTime.parse(map['day'] as String),
          onTimeCount: map['on_time_trips'] as int? ?? 0,
          totalCount: map['total_trips'] as int? ?? 0,
        );
      }).toList();
    } catch (e) {
      throw Exception('Failed to load on-time stats: $e');
    }
  }


  Future<List<TrainStatus>> fetchRecentTrainDelays({
    String? lineId,
    String? stationId,
    int limit = 20,
  }) async {
    try {
      final data = await invokeFunction(
        'get-recent-train-delays',
        queryParameters: {
          if (stationId != null) 'station_id': stationId,
          if (lineId != null) 'line': lineId,
          'limit': '$limit',
        },
      );
      return (data as List)
          .map((row) => TrainStatus.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load recent train delays: $e');
    }
  }

  Future<List<RouteSuggestion>> fetchRouteSuggestionCandidates(String userId) async {
    try {
      final data = await invokeFunction('get-route-suggestions');
      return (data as List)
          .map((row) => RouteSuggestion.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load route suggestions: $e');
    }
  }
}
