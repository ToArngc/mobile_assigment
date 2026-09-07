import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';
import 'supabase_service.dart';

/// Read/update the signed-in user's own `profiles` row.
class ProfileRepository {
  final _client = SupabaseService.client;

  Future<Profile> getProfile(String userId) async {
    final data = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();
    return Profile.fromJson(data);
  }

  /// Older accounts can exist in Auth without a matching profiles row.
  /// Create that missing row on first Profile-screen visit instead of
  /// showing the PostgREST "0 rows" error.
  Future<Profile> getOrCreateProfile({
    required String userId,
    required String fallbackUsername,
  }) async {
    final existing = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (existing != null) return Profile.fromJson(existing);

    try {
      final created = await _client
          .from('profiles')
          .insert({'id': userId, 'username': fallbackUsername})
          .select()
          .single();
      return Profile.fromJson(created);
    } on PostgrestException catch (e) {
      if (e.code != '23505') rethrow;
      final profile = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
      return Profile.fromJson(profile);
    }
  }

  /// Throws with a friendly message if [username] is already taken
  /// (`profiles.username` is UNIQUE — Postgrest code 23505).
  Future<void> updateUsername(String userId, String username) async {
    try {
      await _client.from('profiles').upsert({
        'id': userId,
        'username': username.trim(),
      });
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw Exception('That username is already taken.');
      }
      rethrow;
    }
  }
}
