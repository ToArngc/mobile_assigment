import 'package:supabase_flutter/supabase_flutter.dart';

import 'edge_function_client.dart';
import 'supabase_service.dart';

/// Email + password authentication, per design doc §7.
///
/// Sign up also creates the matching `profiles` row (id + username) via
/// create-profile. `profiles.username` has a UNIQUE constraint in the
/// schema, so a taken username surfaces as a 409 from the function rather
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

    final needsEmailConfirmation = response.session == null;

    // Reconciliation with get-profile's own lazy auto-create: create-profile
    // is JWT-scoped and needs an active session to authenticate as this
    // user, which only exists immediately when email confirmation is off.
    // When it's on, there's no session yet and this call would 401, so it's
    // skipped — get-profile's auto-create (fallback username "Rider <id>")
    // becomes the fallback path the first time the user opens the Profile
    // screen after confirming. That means a confirmed-email sign-up loses
    // the username typed here in favor of the generic fallback — a known
    // gap worth a team call on whether it's acceptable, or whether
    // create-profile should instead be called right after the user's first
    // post-confirmation sign-in.
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
