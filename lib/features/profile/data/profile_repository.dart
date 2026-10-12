import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/profile.dart';

abstract interface class ProfileRepository {
  Future<Profile> fetch(String userId);
  Future<Profile> save(Profile profile);
}

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);

  final SupabaseClient _client;

  static const _columns =
      'user_id, display_name, accent, theme_mode, kantong_view, '
      'tracking_started_on';

  @override
  Future<Profile> fetch(String userId) async {
    final row = await _client
        .from('profiles')
        .select(_columns)
        .eq('user_id', userId)
        .single();
    return Profile.fromJson(row);
  }

  @override
  Future<Profile> save(Profile profile) async {
    final row = await _client
        .from('profiles')
        .update(profile.toUpdateJson())
        .eq('user_id', profile.userId)
        .select(_columns)
        .single();
    return Profile.fromJson(row);
  }
}
