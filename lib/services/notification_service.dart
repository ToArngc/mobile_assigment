import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;















class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;



  static const int _weeklySummaryNotificationId = 90001;

  static Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();




    tz.setLocalLocation(tz.local);

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _plugin.initialize(settings);


    await _plugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();



    await _plugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();

    _initialized = true;
  }




  static Future<void> scheduleLeaveByReminder({
    required int id,
    required DateTime leaveByTime,
    required String stationLabel,
  }) async {

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
      matchDateTimeComponents: null,
    );
  }

  static Future<void> cancelReminder(int id) async {
    await _plugin.cancel(id);
  }







  static Future<void> showWeeklySummary({
    required int rideCount,
    double? onTimePercentage,
    double? averageDelayMinutes,
  }) async {
    final rideLabel = rideCount == 1 ? '1 ride' : '$rideCount rides';
    final body = onTimePercentage == null || averageDelayMinutes == null
        ? '$rideLabel this week. Not enough matching arrival data for on-time stats yet.'
        : '$rideLabel this week, ${onTimePercentage.round()}% on-time, '
            'avg ${averageDelayMinutes.round()} min delay.';

    await _plugin.show(
      _weeklySummaryNotificationId,
      'Your week on the rails',
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'weekly_summary_channel',
          'Weekly Commute Summary',
          channelDescription: 'A weekly digest of your logged rides',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }


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
