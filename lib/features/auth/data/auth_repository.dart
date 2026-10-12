import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Who is signed in, as far as the app cares.
@immutable
class AuthSession {
  const AuthSession({
    required this.userId,
    required this.email,
    this.recovering = false,
  });

  final String userId;
  final String email;

  /// Opened from a password-reset email; the user must set a new password.
  final bool recovering;

  @override
  bool operator ==(Object other) =>
      other is AuthSession &&
      other.userId == userId &&
      other.email == email &&
      other.recovering == recovering;

  @override
  int get hashCode => Object.hash(userId, email, recovering);
}

/// Result of a sign-up: either signed in, or waiting for email confirmation.
enum SignUpOutcome { signedIn, confirmEmail }

abstract interface class AuthRepository {
  AuthSession? get current;
  Stream<AuthSession?> changes();

  Future<void> signIn({required String email, required String password});
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
    required String displayName,
  });
  Future<void> sendPasswordReset(String email);
  Future<void> updatePassword(String password);
  Future<void> signOut();

  /// Deletes the account and every row it owns (PRD F-AUTH-6).
  Future<void> deleteAccount();
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  /// Where email links return to. On web this is the page the app runs on;
  /// on Android Supabase falls back to the project's Site URL.
  String? get _redirect =>
      kIsWeb ? Uri.base.removeFragment().replace(query: '').toString() : null;

  AuthSession? _from(Session? s, {bool recovering = false}) => s == null
      ? null
      : AuthSession(
          userId: s.user.id,
          email: s.user.email ?? '',
          recovering: recovering,
        );

  @override
  AuthSession? get current => _from(_auth.currentSession);

  @override
  Stream<AuthSession?> changes() => _auth.onAuthStateChange.map(
    (e) => _from(
      e.session,
      recovering: e.event == AuthChangeEvent.passwordRecovery,
    ),
  );

  @override
  Future<void> signIn({required String email, required String password}) =>
      _auth.signInWithPassword(email: email.trim(), password: password);

  @override
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final res = await _auth.signUp(
      email: email.trim(),
      password: password,
      data: {'display_name': displayName.trim()},
      emailRedirectTo: _redirect,
    );
    return res.session == null
        ? SignUpOutcome.confirmEmail
        : SignUpOutcome.signedIn;
  }

  @override
  Future<void> sendPasswordReset(String email) =>
      _auth.resetPasswordForEmail(email.trim(), redirectTo: _redirect);

  @override
  Future<void> updatePassword(String password) =>
      _auth.updateUser(UserAttributes(password: password));

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> deleteAccount() async {
    await _client.rpc<void>('delete_account');
    await _auth.signOut();
  }
}
