import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kekayaanku/app.dart';
import 'package:kekayaanku/core/supabase/supabase_providers.dart';
import 'package:kekayaanku/core/theme/app_colors.dart';
import 'package:kekayaanku/features/auth/application/auth_controller.dart';
import 'package:kekayaanku/features/auth/data/auth_repository.dart';
import 'package:kekayaanku/features/portfolios/application/kantong_controller.dart';
import 'package:kekayaanku/features/portfolios/data/kantong_repository.dart';
import 'package:kekayaanku/features/portfolios/domain/kantong.dart';
import 'package:kekayaanku/features/profile/application/profile_controller.dart';
import 'package:kekayaanku/features/profile/data/profile_repository.dart';
import 'package:kekayaanku/features/profile/domain/profile.dart';

const testUser = AuthSession(userId: 'u1', email: 'ilham@example.com');

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({AuthSession? signedIn}) : _current = signedIn;

  final _ctrl = StreamController<AuthSession?>.broadcast();
  AuthSession? _current;
  bool requireEmailConfirmation = false;
  Object? signInError;
  final calls = <String>[];

  void emit(AuthSession? s) {
    _current = s;
    _ctrl.add(s);
  }

  @override
  AuthSession? get current => _current;

  @override
  Stream<AuthSession?> changes() => _ctrl.stream;

  @override
  Future<void> signIn({required String email, required String password}) async {
    calls.add('signIn:$email');
    if (signInError != null) throw signInError!;
    emit(AuthSession(userId: 'u1', email: email));
  }

  @override
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    calls.add('signUp:$email:$displayName');
    if (requireEmailConfirmation) return SignUpOutcome.confirmEmail;
    emit(AuthSession(userId: 'u1', email: email));
    return SignUpOutcome.signedIn;
  }

  @override
  Future<void> sendPasswordReset(String email) async =>
      calls.add('reset:$email');

  @override
  Future<void> updatePassword(String password) async =>
      calls.add('updatePassword');

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    emit(null);
  }

  @override
  Future<void> deleteAccount() async {
    calls.add('deleteAccount');
    emit(null);
  }
}

class FakeProfileRepository implements ProfileRepository {
  Profile? stored;

  @override
  Future<Profile> fetch(String userId) async => stored ??= Profile(
    userId: userId,
    displayName: 'Ilham',
    accent: AppAccent.amber,
    themeMode: ThemeMode.dark,
    kantongView: KantongView.list,
    trackingStartedOn: DateTime(2026, 10, 12),
  );

  @override
  Future<Profile> save(Profile profile) async => stored = profile;
}

class FakeKantongRepository implements KantongRepository {
  FakeKantongRepository([List<Kantong>? initial]) : items = [...?initial];

  final List<Kantong> items;
  Object? listError;
  Completer<void>? listGate;
  int _seq = 0;

  @override
  Future<List<Kantong>> list() async {
    if (listGate != null) await listGate!.future;
    if (listError != null) throw listError!;
    return [...items]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  Kantong _build(String id, KantongDraft d, {int? order, DateTime? archived}) =>
      Kantong(
        id: id,
        name: d.name.trim(),
        emoji: d.emoji,
        color: d.color,
        cashEnabled: d.cashEnabled,
        note: d.note.trim().isEmpty ? null : d.note.trim(),
        sortOrder: order ?? items.length,
        archivedAt: archived,
        createdAt: DateTime(2026, 10, 12),
      );

  @override
  Future<Kantong> create(KantongDraft draft) async {
    final k = _build('k${++_seq}', draft);
    items.add(k);
    return k;
  }

  @override
  Future<Kantong> update(String id, KantongDraft draft) async {
    final i = items.indexWhere((k) => k.id == id);
    final old = items[i];
    return items[i] = _build(
      id,
      draft,
      order: old.sortOrder,
      archived: old.archivedAt,
    );
  }

  @override
  Future<Kantong> setArchived(String id, {required bool archived}) async {
    final i = items.indexWhere((k) => k.id == id);
    final old = items[i];
    return items[i] = _build(
      id,
      old.toDraft(),
      order: old.sortOrder,
      archived: archived ? DateTime(2026, 10, 13) : null,
    );
  }

  @override
  Future<void> delete(String id) async => items.removeWhere((k) => k.id == id);

  @override
  Future<void> reorder(List<String> orderedIds) async {
    for (final (i, id) in orderedIds.indexed) {
      final j = items.indexWhere((k) => k.id == id);
      items[j] = _build(
        id,
        items[j].toDraft(),
        order: i,
        archived: items[j].archivedAt,
      );
    }
  }
}

Kantong kantongFixture(
  String id,
  String name, {
  String emoji = '📈',
  KantongColor color = KantongColor.mint,
  int order = 0,
}) => Kantong(
  id: id,
  name: name,
  emoji: emoji,
  color: color,
  cashEnabled: true,
  note: null,
  sortOrder: order,
  archivedAt: null,
  createdAt: DateTime(2026, 10, 12),
);

class TestHarness {
  TestHarness({AuthSession? signedIn = testUser, List<Kantong>? kantong})
    : auth = FakeAuthRepository(signedIn: signedIn),
      kantong = FakeKantongRepository(kantong);

  final FakeAuthRepository auth;
  final FakeProfileRepository profile = FakeProfileRepository();
  final FakeKantongRepository kantong;

  Widget app() => ProviderScope(
    retry: (_, _) => null,
    overrides: [
      supabaseConfiguredProvider.overrideWithValue(true),
      authRepositoryProvider.overrideWithValue(auth),
      profileRepositoryProvider.overrideWithValue(profile),
      kantongRepositoryProvider.overrideWithValue(kantong),
    ],
    child: const KekayaankuApp(),
  );
}

/// Sets the logical screen size for one test.
void setScreen(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

const phone = Size(360, 760);
const desktop = Size(1280, 800);
