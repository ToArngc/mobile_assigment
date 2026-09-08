import 'package:supabase_flutter/supabase_flutter.dart';

import 'edge_function_client.dart';
import 'supabase_service.dart';










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





    if (user.identities?.isEmpty ?? false) {
      throw Exception(
        'An account with this email already exists. Please log in.',
      );
    }

    final needsEmailConfirmation = response.session == null;







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
