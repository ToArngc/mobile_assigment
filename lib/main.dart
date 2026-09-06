import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'services/auth_service.dart';
import 'services/delay_alert_service.dart';
import 'services/notification_service.dart';
import 'services/ride_detection_service.dart';
import 'services/supabase_service.dart';
import 'shared_widgets/app_shell.dart';
import 'modules/auth/screens/auth_gate.dart';
import 'services/notification_service.dart';
import 'services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  await NotificationService.initialize();
  await DelayAlertService.instance.start();
  await RideDetectionService().start();
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
