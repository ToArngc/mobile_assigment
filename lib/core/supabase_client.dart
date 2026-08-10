import 'package:supabase_flutter/supabase_flutter.dart';

/// Global Supabase client access.
///
/// Call [SupabaseService.initialize] once in main() before runApp().
/// After that, use `SupabaseService.client` anywhere to run queries.
class SupabaseService {
  static late final SupabaseClient client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: 'YOUR_SUPABASE_URL',
      anonKey: 'YOUR_SUPABASE_ANON_KEY',
    );
    client = Supabase.instance.client;
  }
}

/*
Usage in main.dart:

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  runApp(const MyApp());
}
*/