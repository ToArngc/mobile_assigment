import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';
import 'edge_function_client.dart';

/// Read/update the signed-in user's own `profiles` row.
class ProfileRepository {
  /// get-profile is JWT-scoped to the caller — [userId] is kept in the
  /// signature for existing callers but must always be the current user's
  /// own id.
  Future<Profile> getProfile(String userId) async {
    final data = await invokeFunction('get-profile');
    return Profile.fromJson(data as Map<String, dynamic>);
  }

  /// get-profile already has get-or-create semantics server-side: it
  /// creates a row with a "Rider <first 6 chars of id>" fallback username
  /// if none exists yet (same format [fallbackUsername] computes), so this
  /// just calls it. [fallbackUsername] is unused now but kept in the
  /// signature for existing callers.
  Future<Profile> getOrCreateProfile({
    required String userId,
    required String fallbackUsername,
  }) async {
    final data = await invokeFunction('get-profile');
    return Profile.fromJson(data as Map<String, dynamic>);
  }

  /// Throws with a friendly message if [username] is already taken —
  /// update-profile responds 409 with `{ "error": "That username is
  /// already taken." }`, which invokeFunction surfaces as the exception
  /// message directly.
  Future<void> updateUsername(String userId, String username) async {
    await invokeFunction(
      'update-profile',
      method: HttpMethod.post,
      body: {'username': username.trim()},
    );
  }
}
