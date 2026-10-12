import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kekayaanku/features/auth/data/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../helpers/fakes.dart';

void main() {
  testWidgets('signed out opens on Masuk and validates the form', (t) async {
    final h = TestHarness(signedIn: null);
    await t.pumpWidget(h.app());
    await t.pumpAndSettle();

    expect(find.text('Masuk'), findsWidgets);
    await t.tap(find.widgetWithText(FilledButton, 'Masuk'));
    await t.pumpAndSettle();
    expect(find.text('Isi alamat email.'), findsOneWidget);
    expect(find.text('Isi kata sandi.'), findsOneWidget);
    expect(h.auth.calls, isEmpty);
  });

  testWidgets('signing in lands on Overview', (t) async {
    final h = TestHarness(signedIn: null);
    await t.pumpWidget(h.app());
    await t.pumpAndSettle();

    await t.enterText(find.byType(TextFormField).at(0), 'ilham@example.com');
    await t.enterText(find.byType(TextFormField).at(1), 'rahasia123');
    await t.tap(find.widgetWithText(FilledButton, 'Masuk'));
    await t.pumpAndSettle();

    expect(h.auth.calls, ['signIn:ilham@example.com']);
    expect(find.text('Overview'), findsOneWidget);
  });

  testWidgets('wrong password shows an Indonesian message', (t) async {
    final h = TestHarness(signedIn: null)
      ..auth.signInError = const AuthException(
        'Invalid login credentials',
        code: 'invalid_credentials',
      );
    await t.pumpWidget(h.app());
    await t.pumpAndSettle();

    await t.enterText(find.byType(TextFormField).at(0), 'ilham@example.com');
    await t.enterText(find.byType(TextFormField).at(1), 'salah');
    await t.tap(find.widgetWithText(FilledButton, 'Masuk'));
    await t.pumpAndSettle();

    expect(find.text('Email atau kata sandi salah.'), findsOneWidget);
  });

  testWidgets('sign-up waiting for email confirmation says so', (t) async {
    final h = TestHarness(signedIn: null)..auth.requireEmailConfirmation = true;
    await t.pumpWidget(h.app());
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(TextButton, 'Daftar'));
    await t.pumpAndSettle();

    await t.enterText(find.byType(TextFormField).at(0), 'Ilham');
    await t.enterText(find.byType(TextFormField).at(1), 'ilham@example.com');
    await t.enterText(find.byType(TextFormField).at(2), 'pendek');
    await t.tap(find.widgetWithText(FilledButton, 'Daftar'));
    await t.pumpAndSettle();
    expect(find.text('Minimal 8 karakter.'), findsOneWidget);

    await t.enterText(find.byType(TextFormField).at(2), 'cukup-panjang');
    await t.tap(find.widgetWithText(FilledButton, 'Daftar'));
    await t.pumpAndSettle();

    expect(h.auth.calls, ['signUp:ilham@example.com:Ilham']);
    expect(find.text('Cek email Anda'), findsOneWidget);
  });

  testWidgets('a recovery link goes straight to Kata sandi baru', (t) async {
    final h = TestHarness();
    await t.pumpWidget(h.app());
    await t.pumpAndSettle();

    h.auth.emit(
      const AuthSession(
        userId: 'u1',
        email: 'ilham@example.com',
        recovering: true,
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Kata sandi baru'), findsOneWidget);
  });

  testWidgets('Keluar from Profil returns to Masuk', (t) async {
    final h = TestHarness();
    await t.pumpWidget(h.app());
    await t.pumpAndSettle();

    await t.tap(find.bySemanticsLabel('Buka profil'));
    await t.pumpAndSettle();
    expect(find.text('Tracking sejak 12 Okt 2026'), findsOneWidget);

    await t.tap(find.text('Keluar'));
    await t.pumpAndSettle();
    expect(h.auth.calls, contains('signOut'));
    expect(find.widgetWithText(FilledButton, 'Masuk'), findsOneWidget);
  });
}
