import 'package:flutter/material.dart';
import 'core/supabase_client.dart';
import 'core/auth_service.dart';
import 'modules/module1_explorer/repositories/station_repository.dart';
import 'modules/module3_fault/screens/report_issue_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  await AuthService.ensureSignedIn();
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

/// Separate widget so its `context` is a descendant of MaterialApp —
/// required for ScaffoldMessenger.of(context) / Scaffold.of(context) to work.
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
            const SizedBox(height: 16),

            ElevatedButton.icon(
              icon: const Icon(Icons.flag_outlined),
              label: const Text('Report an issue'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ReportIssueScreen()),
                );
              },
            ),

            ElevatedButton(
              onPressed: () async {
                final stations = await StationRepository().getAllStations();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Read OK: got ${stations.length} stations')),
                  );
                }
              },
              child: const Text('Test read (stations)'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                final userId = AuthService.currentUserId;
                if (userId == null) return;
                try {
                  await SupabaseService.client.from('mute_settings').upsert({
                    'user_id': userId,
                    'muted_until': null,
                    'updated_at': DateTime.now().toIso8601String(),
                  });
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Write OK: mute_settings upserted')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Write failed: $e')),
                    );
                  }
                }
              },
              child: const Text('Test write (mute_settings)'),
            ),
          ],
        ),
      ),
    );
  }
}