import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';
import 'edge_function_client.dart';


class ProfileRepository {

  Future<Profile> getOrCreateProfile({
    required String userId,
    required String fallbackUsername,
  }) async {
    final data = await invokeFunction('get-profile');
    return Profile.fromJson(data as Map<String, dynamic>);
  }

  Future<void> updateUsername(String userId, String username) async {
    await invokeFunction(
      'update-profile',
      method: HttpMethod.post,
      body: {'username': username.trim()},
    );
  }
}
