import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_assigment/models/saved_route.dart';
import 'package:mobile_assigment/models/saved_station.dart';
import 'package:mobile_assigment/models/weekly_ride_summary.dart';

void main() {
  group('SavedRoute', () {
    test('accepts a GPS-to-target route with no destination station', () {
      final route = SavedRoute.fromJson({
        'id': 'route-1',
        'user_id': 'user-1',
        'origin_station_id': 'station-1',
        'destination_station_id': null,
        'walking_minutes': 12,
        'created_at': '2026-09-09T02:00:00Z',
        'origin_station': {'name': 'Angkasapuri', 'line': 'Port Klang'},
      });

      expect(route.destinationStationId, isNull);
      expect(route.stationName, 'Angkasapuri');
      expect(route.stationLine, 'Port Klang');
      expect(route.walkingMinutes, 12);
    });

    test('skips malformed saved-route records instead of crashing a list', () {
      expect(
        SavedRoute.tryFromJson({
          'id': 'route-1',
          'user_id': 'user-1',
          'origin_station_id': null,
          'created_at': '2026-09-09T02:00:00Z',
        }),
        isNull,
      );
    });
  });

  test('SavedStation reads joined station details and preserves enabled state', () {
    final station = SavedStation.fromJson({
      'id': 'saved-1',
      'user_id': 'user-1',
      'station_id': 'station-1',
      'alert_delay_threshold': 5,
      'active_days': ['Mon', 'Tue'],
      'enabled': false,
      'created_at': '2026-09-09T02:00:00Z',
      'stations': {'name': 'Kuala Lumpur', 'line': 'KTM Komuter'},
    });

    expect(station.stationName, 'Kuala Lumpur');
    expect(station.stationLine, 'KTM Komuter');
    expect(station.enabled, isFalse);
    expect(station.activeDays, ['Mon', 'Tue']);
  });

  test('WeeklyRideSummary keeps unavailable delay statistics as null', () {
    final summary = WeeklyRideSummary.fromJson({
      'ride_count': 2,
      'on_time_count': 0,
      'on_time_percentage': null,
      'avg_delay_minutes': null,
      'rides': [
        {
          'station_name': 'Serdang',
          'detected_at': '2026-09-09T02:00:00Z',
          'delay_minutes': null,
        },
      ],
    });

    expect(summary.rideCount, 2);
    expect(summary.hasDelayData, isFalse);
    expect(summary.averageDelayMinutes, isNull);
    expect(summary.rides.single.stationName, 'Serdang');
    expect(summary.rides.single.delayMinutes, isNull);
  });

  test('WeeklyRideSummary averages late trains without early arrivals offsetting them', () {
    final summary = WeeklyRideSummary.fromJson({
      'ride_count': 4,
      'on_time_count': 2,
      'on_time_percentage': 50,
      'avg_delay_minutes': 0,
      'rides': [
        {'detected_at': '2026-09-09T02:00:00Z', 'delay_minutes': 8},
        {'detected_at': '2026-09-09T03:00:00Z', 'delay_minutes': 10},
        {'detected_at': '2026-09-09T04:00:00Z', 'delay_minutes': -4},
        {'detected_at': '2026-09-09T05:00:00Z', 'delay_minutes': -3},
      ],
    });

    expect(summary.averageDelayMinutes, 9);
  });
}
