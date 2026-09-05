import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// Email + password authentication, per design doc §7.
///
/// Sign up also creates the matching `profiles` row (id + username).
/// `profiles.username` has a UNIQUE constraint in the schema, so a taken
/// username surfaces as a Postgrest unique-violation (code 23505) rather
/// than needing a separate existence check.
class AuthService {
  static SupabaseClient get _client => SupabaseService.client;

  static Session? get currentSession => _client.auth.currentSession;
  static String? get currentUserId => _client.auth.currentUser?.id;
  static Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  static Future<void> signIn({required String email, required String password}) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  static Future<void> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    final response = await _client.auth.signUp(email: email, password: password);
    final user = response.user;
    if (user == null) {
      throw Exception('Sign up failed — please try again.');
    }

    try {
      await _client.from('profiles').insert({
        'id': user.id,
        'username': username.trim(),
      });
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw Exception('That username is already taken.');
      }
      rethrow;
    }
  }

  static Future<void> signOut() => _client.auth.signOut();
}
