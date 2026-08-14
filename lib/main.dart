import 'package:flutter/material.dart';
import 'core/supabase_client.dart';
import 'core/auth_service.dart';

import 'modules/module1_explorer/repositories/station_repository.dart';
import 'modules/module4_alerts/screens/alerts_home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  await AuthService.ensureSignedIn();
  await NotificationService.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OnJejak',
      home: const HomePage(),
    );
  }
}

/// Temporary landing page — will be replaced by the real bottom-nav /
/// module hub once Modules 1-3 have screens too. For now it's just a
/// launcher into whichever module you're actively working on.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OnJejak')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Signed in as: ${AuthService.currentUserId ?? "not signed in"}'),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.notifications_active),
              label: const Text('Open Alerts (Module 4)'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AlertsHomeScreen()),
                );
              },
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () async {
                final stations = await StationRepository().getAllStations();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Debug: got ${stations.length} stations')),
                  );
                }
              },
              child: const Text('Debug: test Supabase read'),
            ),
          ],
        ),
      ),
    );
  }
}