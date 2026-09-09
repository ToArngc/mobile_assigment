import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class MalaysiaTime {
  MalaysiaTime._();

  static const locationName = 'Asia/Kuala_Lumpur';

  static tz.Location? _location;

  static void initialize() {
    if (_location != null) return;
    tz_data.initializeTimeZones();
    _location = tz.getLocation(locationName);
  }

  static tz.Location get location {
    final initializedLocation = _location;
    if (initializedLocation == null) {
      throw StateError('MalaysiaTime.initialize() must be called first.');
    }
    return initializedLocation;
  }

  static tz.TZDateTime now() => tz.TZDateTime.now(location);

  static tz.TZDateTime fromUtc(DateTime instant) =>
      tz.TZDateTime.from(instant.toUtc(), location);

  static bool isCommuteWindow(DateTime instant) {
    final malaysiaTime = fromUtc(instant);
    final minuteOfDay = malaysiaTime.hour * 60 + malaysiaTime.minute;
    return (minuteOfDay >= 7 * 60 && minuteOfDay < 10 * 60) ||
        (minuteOfDay >= 17 * 60 && minuteOfDay < 20 * 60);
  }
}
