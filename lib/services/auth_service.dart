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
  static Stream<AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange;

  static Future<void> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  /// Returns true when Supabase requires the user to confirm their email
  /// before a session can be created.
  static Future<bool> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );
    final user = response.user;
    if (user == null) {
      throw Exception('Sign up failed — please try again.');
    }

    // With email enumeration protection enabled, Supabase returns a user
    // object with no identities for an existing email. Trying to create a
    // profile from that synthetic id causes the foreign-key error shown in
    // the sign-up screen, so turn it into a useful instruction instead.
    if (user.identities?.isEmpty ?? false) {
      throw Exception(
        'An account with this email already exists. Please log in.',
      );
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

    return response.session == null;
  }

  static Future<void> signOut() => _client.auth.signOut();
}
