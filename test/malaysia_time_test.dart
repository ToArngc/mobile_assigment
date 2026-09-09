import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_assigment/core/malaysia_time.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(MalaysiaTime.initialize);

  test('converts a UTC API timestamp to Malaysia time', () {
    final utcValue = DateTime.parse('2026-09-08T23:00:00.000Z');

    final malaysiaValue = MalaysiaTime.fromUtc(utcValue);

    expect(malaysiaValue.year, 2026);
    expect(malaysiaValue.month, 9);
    expect(malaysiaValue.day, 9);
    expect(malaysiaValue.hour, 7);
    expect(malaysiaValue.minute, 0);
    expect(malaysiaValue.location.name, MalaysiaTime.locationName);
  });

  test('uses only the two Malaysia commute windows', () {
    final cases = <({int hour, int minute, bool expected})>[
      (hour: 6, minute: 59, expected: false),
      (hour: 7, minute: 0, expected: true),
      (hour: 9, minute: 59, expected: true),
      (hour: 10, minute: 0, expected: false),
      (hour: 16, minute: 59, expected: false),
      (hour: 17, minute: 0, expected: true),
      (hour: 19, minute: 59, expected: true),
      (hour: 20, minute: 0, expected: false),
    ];

    for (final boundary in cases) {
      final malaysiaValue = tz.TZDateTime(
        MalaysiaTime.location,
        2026,
        9,
        9,
        boundary.hour,
        boundary.minute,
      );

      expect(
        MalaysiaTime.isCommuteWindow(malaysiaValue),
        boundary.expected,
        reason:
            '${boundary.hour.toString().padLeft(2, '0')}:'
            '${boundary.minute.toString().padLeft(2, '0')} MYT',
      );
    }
  });
}
