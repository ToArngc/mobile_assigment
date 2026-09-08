import 'dart:async';

import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'services/auth_service.dart';
import 'services/delay_alert_service.dart';
import 'services/notification_service.dart';
import 'services/ride_detection_service.dart';
import 'services/supabase_service.dart';
import 'modules/auth/screens/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  runApp(const MyApp());

  await NotificationService.initialize();

  final rideDetection = RideDetectionService();
  AuthService.authStateChanges.listen((authState) {
    if (authState.session == null) {
      DelayAlertService.instance.stop();
      rideDetection.stop();
      return;
    }
    unawaited(DelayAlertService.instance.start());
    unawaited(rideDetection.start());
  });

}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OnJejak',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      home: const AuthGate(),
    );
  }
}
