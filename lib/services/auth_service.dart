import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// Handles anonymous authentication.
///
/// OnJejak doesn't need real accounts (no login screen, no email/password) —
/// every device just needs a stable user_id so RLS policies on
/// saved_stations / saved_routes / mute_settings / ride_logs
/// know which rows belong to which user.
///
/// Call [AuthService.ensureSignedIn] once in main(), after
/// SupabaseService.initialize() and before runApp().
class AuthService {
  static Future<void> ensureSignedIn() async {
    final client = SupabaseService.client;

    // Supabase persists the session locally, so on most app launches
    // there's already a signed-in anonymous user from last time.
    if (client.auth.currentUser != null) return;

    try {
      await client.auth.signInAnonymously();
    } catch (e) {
      // If this fails (e.g. anonymous sign-ins disabled in the Supabase
      // dashboard under Authentication > Providers), every saved_*
      // write will fail too — surface it loudly during development.
      // ignore: avoid_print
      print('Anonymous sign-in failed: $e');
      rethrow;
    }
  }

  /// Convenience getter — most repositories/providers need this.
  static String? get currentUserId => SupabaseService.client.auth.currentUser?.id;
}
