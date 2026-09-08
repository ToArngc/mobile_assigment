import 'package:supabase_flutter/supabase_flutter.dart';

import 'edge_function_client.dart';
import 'supabase_service.dart';

/// Email + password authentication, per design doc §7.
///
/// Sign up attaches the chosen username as auth user_metadata so it
/// survives regardless of whether email confirmation delays the session,
/// and also creates the matching `profiles` row (id + username) via
/// create-profile when a session already exists. `profiles.username` has a
/// UNIQUE constraint in the schema, so a taken username surfaces as a 409
/// from create-profile (or a silent fallback from get-profile's
/// auto-create) rather than needing a separate existence check.
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
      data: {'username': username.trim()},
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

    final needsEmailConfirmation = response.session == null;

    // The username is already attached as auth user_metadata above, so it
    // survives even when there's no session yet (email confirmation on) —
    // get-profile's auto-create reads it from there. When a session exists
    // immediately (confirmation off), this call is just a defensive
    // backstop that creates the row eagerly instead of waiting for the
    // user's first Profile screen visit.
    if (!needsEmailConfirmation) {
      await invokeFunction(
        'create-profile',
        method: HttpMethod.post,
        body: {'username': username.trim()},
      );
    }

    return needsEmailConfirmation;
  }

  static Future<void> signOut() => _client.auth.signOut();
}
