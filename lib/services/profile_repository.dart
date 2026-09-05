import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';
import 'supabase_service.dart';

/// Read/update the signed-in user's own `profiles` row.
class ProfileRepository {
  final _client = SupabaseService.client;

  Future<Profile> getProfile(String userId) async {
    final data = await _client.from('profiles').select().eq('id', userId).single();
    return Profile.fromJson(data);
  }

  /// Throws with a friendly message if [username] is already taken
  /// (`profiles.username` is UNIQUE — Postgrest code 23505).
  Future<void> updateUsername(String userId, String username) async {
    try {
      await _client.from('profiles').update({'username': username.trim()}).eq('id', userId);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw Exception('That username is already taken.');
      }
      rethrow;
    }
  }
}
