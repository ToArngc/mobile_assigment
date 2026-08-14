import 'package:firebase_messaging/firebase_messaging.dart';
import '../core/supabase_client.dart';

/// Handles Firebase Cloud Messaging setup and registers the device token
/// against the current Supabase user, so the backend (or a Supabase Edge
/// Function) can target push notifications per user.
///
/// Call [FcmService.initialize] once after the user is signed in
/// (anonymous or full auth) — it needs auth.uid() to store the token.
class FcmService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static Future<void> initialize() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      // User declined notifications — Quick Mute / Alert Rules / Leave-By
      // Planner won't be able to push. Surface this in Module 4's UI
      // (e.g. a banner telling the user to enable notifications in settings).
      return;
    }

    final token = await _messaging.getToken();
    if (token != null) {
      await _saveToken(token);
    }

    // Re-save whenever FCM rotates the token.
    _messaging.onTokenRefresh.listen(_saveToken);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // Foreground messages don't show a system notification automatically.
      // Wire this to flutter_local_notifications if you want a banner
      // while the app is open (common for Leave-By Planner alerts).
    });
  }

  static Future<void> _saveToken(String token) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) return; // not signed in yet — nothing to attach to

    try {
      await SupabaseService.client.from('device_tokens').upsert({
        'user_id': userId,
        'fcm_token': token,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Token registration failing shouldn't crash the app — alerts just
      // won't reach this device until the next successful sync.
      // ignore: avoid_print
      print('FCM token save failed: $e');
    }
  }
}