import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'modules/auth/screens/auth_gate.dart';
import 'services/notification_service.dart';
import 'services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  await NotificationService.initialize();
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
