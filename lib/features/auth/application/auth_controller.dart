import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => SupabaseAuthRepository(ref.watch(supabaseClientProvider)),
);

/// The current session, kept in sync with the auth stream.
/// `null` means signed out.
class AuthController extends Notifier<AuthSession?> {
  StreamSubscription<AuthSession?>? _sub;

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  AuthSession? build() {
    if (!ref.watch(supabaseConfiguredProvider)) return null;
    final repo = ref.watch(authRepositoryProvider);
    _sub = repo.changes().listen((s) => state = s);
    ref.onDispose(() => _sub?.cancel());
    return repo.current;
  }

  Future<void> signIn(String email, String password) =>
      _repo.signIn(email: email, password: password);

  Future<SignUpOutcome> signUp(String email, String password, String name) =>
      _repo.signUp(email: email, password: password, displayName: name);

  Future<void> sendPasswordReset(String email) =>
      _repo.sendPasswordReset(email);

  Future<void> updatePassword(String password) async {
    await _repo.updatePassword(password);
    final s = state;
    if (s != null) {
      state = AuthSession(userId: s.userId, email: s.email);
    }
  }

  Future<void> signOut() => _repo.signOut();

  Future<void> deleteAccount() => _repo.deleteAccount();
}

final authControllerProvider = NotifierProvider<AuthController, AuthSession?>(
  AuthController.new,
);

/// Password rule shown in forms. Supabase enforces the same minimum
/// (supabase/config.toml `minimum_password_length`; set it in the dashboard
/// for production too).
const int kMinPasswordLength = 8;

String? validateEmail(String? v) {
  final s = v?.trim() ?? '';
  if (s.isEmpty) return 'Isi alamat email.';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)) {
    return 'Alamat email belum lengkap.';
  }
  return null;
}

String? validateNewPassword(String? v) {
  if ((v ?? '').length < kMinPasswordLength) {
    return 'Minimal $kMinPasswordLength karakter.';
  }
  return null;
}
