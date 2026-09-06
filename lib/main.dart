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
  await NotificationService.initialize();

  // Module 4 services need the signed-in user's id. AuthGate handles the
  // UI, while this listener starts/stops the foreground services whenever
  // the session changes (including a persisted session at app launch).
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

  runApp(const MyApp());
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
