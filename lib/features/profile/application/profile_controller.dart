import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/application/auth_controller.dart';
import '../data/profile_repository.dart';
import '../domain/profile.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => SupabaseProfileRepository(ref.watch(supabaseClientProvider)),
);

/// The signed-in user's profile; `null` while signed out.
class ProfileController extends AsyncNotifier<Profile?> {
  @override
  Future<Profile?> build() async {
    final userId = ref.watch(authControllerProvider.select((s) => s?.userId));
    if (userId == null) return null;
    return ref.read(profileRepositoryProvider).fetch(userId);
  }

  /// Applies [change] at once and saves it; rolls back if the save fails.
  Future<void> _update(Profile Function(Profile) change) async {
    final before = state.value;
    if (before == null) return;
    state = AsyncData(change(before));
    try {
      final saved = await ref
          .read(profileRepositoryProvider)
          .save(state.value!);
      if (ref.mounted) state = AsyncData(saved);
    } catch (e) {
      if (ref.mounted) state = AsyncData(before);
      rethrow;
    }
  }

  Future<void> setAccent(AppAccent a) => _update((p) => p.copyWith(accent: a));
  Future<void> setThemeMode(ThemeMode m) =>
      _update((p) => p.copyWith(themeMode: m));
  Future<void> setKantongView(KantongView v) =>
      _update((p) => p.copyWith(kantongView: v));
  Future<void> setDisplayName(String name) =>
      _update((p) => p.copyWith(displayName: name.trim()));
}

final profileControllerProvider =
    AsyncNotifierProvider<ProfileController, Profile?>(ProfileController.new);
