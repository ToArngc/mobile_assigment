import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

/// Local (on-device) notification scheduling for Module 4.
///
/// Used specifically for the Leave-By Planner: the "leave by X time"
/// reminder is scheduled locally rather than pushed from a server,
/// because the leave-by time is per-user and recalculated daily —
/// doing that server-side would mean running a background service per
/// user, which is exactly what the team dropped earlier for workload
/// reasons (see the shared architecture notes: GitHub Action replaced
/// an always-on per-device service).
///
/// Known limitation: on some Android OEMs, scheduled alarms can be
/// cleared on device reboot unless the app also listens for
/// BOOT_COMPLETED and reschedules — worth mentioning as a known
/// limitation in the demo rather than something to fully solve here.
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    // Uses the device's local timezone. If your Supabase project stores
    // timestamps in a different zone than the device, double-check the
    // Leave-By calculation still lines up — see the earlier timezone
    // caveat noted for scheduled_time comparisons.
    tz.setLocalLocation(tz.local);

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _plugin.initialize(settings);

    // Android 13+ requires a runtime permission request for notifications.
    await _plugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Exact alarms need a separate permission on Android 12+. Without
    // this, scheduled notifications may fire late/inexact.
    await _plugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();

    _initialized = true;
  }

  /// Schedules a "leave by" reminder. [id] should be stable per route
  /// (e.g. route.id.hashCode) so re-scheduling the same route replaces
  /// the old notification instead of stacking duplicates.
  static Future<void> scheduleLeaveByReminder({
    required int id,
    required DateTime leaveByTime,
    required String stationLabel,
  }) async {
    // Don't schedule for times already in the past.
    if (leaveByTime.isBefore(DateTime.now())) return;

    await _plugin.zonedSchedule(
      id,
      'Time to leave',
      'Leave now for $stationLabel to make your usual train.',
      tz.TZDateTime.from(leaveByTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'leave_by_channel',
          'Leave-By Reminders',
          channelDescription: 'Personalised departure reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: null, // one-off, not repeating daily
    );
  }

  static Future<void> cancelReminder(int id) async {
    await _plugin.cancel(id);
  }

  /// Displays an immediate, foreground-checked Module 4 train-delay alert.
  static Future<void> showDelayAlert({
    required int id,
    required String stationName,
    required String line,
    required int delayMinutes,
  }) async {
    final lineLabel = line.isEmpty ? '' : ' ($line)';
    await _plugin.show(
      id,
      'Train delay alert',
      '$stationName$lineLabel is delayed by $delayMinutes minutes.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'train_delay_channel',
          'Train Delay Alerts',
          channelDescription: 'Personalised alerts for train delays',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}
