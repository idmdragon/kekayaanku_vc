import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kekayaanku/app.dart';
import 'package:kekayaanku/core/supabase/supabase_providers.dart';
import 'package:kekayaanku/core/theme/app_colors.dart';
import 'package:kekayaanku/features/auth/application/auth_controller.dart';
import 'package:kekayaanku/features/auth/data/auth_repository.dart';
import 'package:decimal/decimal.dart';
import 'package:kekayaanku/features/dashboard/domain/summary.dart';
import 'package:kekayaanku/features/holdings/application/finance_providers.dart';
import 'package:kekayaanku/features/holdings/data/finance_repository.dart';
import 'package:kekayaanku/features/holdings/domain/cash_transaction.dart';
import 'package:kekayaanku/features/holdings/domain/holding.dart';
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

/// In-memory stand-in for the SQL layer. It only adds balances up; the
/// real rules are tested in pgTAP (supabase/tests).
class FakeFinanceRepository implements FinanceRepository {
  final holdingsList = <Holding>[];
  final txs = <CashTransaction>[];
  final points = <SnapshotPoint>[];
  final calls = <String>[];
  Object? summaryError;
  Decimal? change;
  int _seq = 0;

  Decimal _balance(String holdingId) => txs
      .where((t) => t.holdingId == holdingId)
      .fold(Decimal.zero, (a, t) => a + t.signedAmount);

  Holding _withQty(Holding h) => Holding(
    id: h.id,
    portfolioId: h.portfolioId,
    category: h.category,
    name: h.name,
    qty: _balance(h.id),
    startedOn: h.startedOn,
    form: h.form,
  );

  String _addTx(
    String holdingId,
    TxType type,
    Decimal amount,
    FlowKind kind, {
    DateTime? date,
    String? note,
  }) {
    final id = 't${++_seq}';
    txs.add(
      CashTransaction(
        id: id,
        holdingId: holdingId,
        holdingName: holdingsList.firstWhere((h) => h.id == holdingId).name,
        date: date ?? DateTime(2026, 10, 12),
        type: type,
        qty: amount,
        amount: amount.abs(),
        flowKind: kind,
        counted: false,
        note: note == null || note.isEmpty ? null : note,
      ),
    );
    return id;
  }

  /// Seeds a savings holding with a balance.
  String seedSavings(String portfolioId, String name, int balance) {
    final id = 'h${++_seq}';
    holdingsList.add(
      Holding(
        id: id,
        portfolioId: portfolioId,
        category: HoldingCategory.savingsIdr,
        name: name,
        qty: Decimal.zero,
        startedOn: DateTime(2026, 10, 1),
        form: SavingsForm.rekening,
      ),
    );
    _addTx(id, TxType.opening, Decimal.fromInt(balance), FlowKind.none);
    return id;
  }

  @override
  Future<DashboardSummary> summary() async {
    if (summaryError != null) throw summaryError!;
    final all = holdingsList.map(_withQty).toList();
    final total = all.fold(Decimal.zero, (a, h) => a + h.qty);
    final byPortfolio = <String, List<Holding>>{};
    for (final h in all) {
      byPortfolio.putIfAbsent(h.portfolioId, () => []).add(h);
    }
    final byCategory = <String, Decimal>{};
    for (final h in all) {
      final key = h.isCash ? 'cash' : 'savings_idr';
      byCategory[key] = (byCategory[key] ?? Decimal.zero) + h.qty;
    }
    return DashboardSummary(
      asOf: DateTime(2026, 10, 12),
      totalAssets: total,
      totalReceivables: Decimal.zero,
      totalDebts: Decimal.zero,
      netWorth: total,
      netDeposits: total,
      flowSince: Decimal.zero,
      change: change,
      changePct: change == null ? null : Decimal.zero,
      baseDate: points.isEmpty ? null : points.first.date,
      firstSnapshotOn: points.isEmpty ? null : points.last.date,
      categories: byCategory,
      portfolios: {
        for (final e in byPortfolio.entries)
          e.key: PortfolioFigures(
            value: e.value.fold(Decimal.zero, (a, h) => a + h.qty),
            cost: e.value.fold(Decimal.zero, (a, h) => a + h.qty),
            unrealized: Decimal.zero,
            cash: e.value
                .where((h) => h.isCash)
                .fold(Decimal.zero, (a, h) => a + h.qty),
            assetCount: e.value.where((h) => !h.isCash).length,
          ),
      },
    );
  }

  @override
  Future<List<SnapshotPoint>> history() async => [...points];

  @override
  Future<List<Holding>> holdings() async => holdingsList.map(_withQty).toList();

  @override
  Future<List<CashTransaction>> transactions({
    String? holdingId,
    String? portfolioId,
  }) async => [
    for (final t in txs.reversed)
      if ((holdingId == null || t.holdingId == holdingId) &&
          (portfolioId == null ||
              holdingsList.any(
                (h) => h.id == t.holdingId && h.portfolioId == portfolioId,
              )))
        t,
  ];

  @override
  Future<String> createSavings({
    required String portfolioId,
    required String name,
    required SavingsForm form,
    required Decimal amount,
  }) async {
    calls.add('createSavings:$portfolioId:$name:${form.name}:$amount');
    final id = 'h${++_seq}';
    holdingsList.add(
      Holding(
        id: id,
        portfolioId: portfolioId,
        category: HoldingCategory.savingsIdr,
        name: name.trim(),
        qty: Decimal.zero,
        startedOn: DateTime(2026, 10, 12),
        form: form,
      ),
    );
    if (amount > Decimal.zero) {
      _addTx(id, TxType.opening, amount, FlowKind.none);
    }
    return id;
  }

  @override
  Future<String> cashHolding(String portfolioId) async {
    final existing = holdingsList
        .where((h) => h.isCash && h.portfolioId == portfolioId)
        .firstOrNull;
    if (existing != null) return existing.id;
    final id = 'cash-$portfolioId';
    holdingsList.add(
      Holding(
        id: id,
        portfolioId: portfolioId,
        category: HoldingCategory.cash,
        name: 'Kas',
        qty: Decimal.zero,
        startedOn: DateTime(2026, 10, 1),
      ),
    );
    return id;
  }

  @override
  Future<void> recordOpening(String holdingId, Decimal amount) async {
    calls.add('recordOpening:$holdingId:$amount');
    _addTx(holdingId, TxType.opening, amount, FlowKind.none);
  }

  @override
  Future<void> recordFlow(
    String holdingId, {
    required bool inflow,
    required Decimal amount,
    required DateTime date,
    String? note,
  }) async {
    calls.add('recordFlow:$holdingId:${inflow ? 'in' : 'out'}:$amount');
    _addTx(
      holdingId,
      inflow ? TxType.deposit : TxType.withdraw,
      amount,
      inflow ? FlowKind.externalIn : FlowKind.externalOut,
      date: date,
      note: note,
    );
  }

  @override
  Future<bool> setBalance(
    String holdingId, {
    required Decimal balance,
    required DateTime date,
    required bool asIncome,
    String? note,
  }) async {
    final delta = balance - _balance(holdingId);
    calls.add('setBalance:$holdingId:$balance:$asIncome');
    if (delta == Decimal.zero) return false;
    _addTx(
      holdingId,
      TxType.adjust,
      delta,
      asIncome
          ? (delta > Decimal.zero ? FlowKind.income : FlowKind.expense)
          : (delta > Decimal.zero ? FlowKind.externalIn : FlowKind.externalOut),
      date: date,
    );
    return true;
  }

  @override
  Future<void> updateTransaction(
    String id, {
    required Decimal amount,
    required DateTime date,
    String? note,
  }) async => calls.add('updateTransaction:$id:$amount');

  @override
  Future<void> deleteTransaction(String id) async {
    calls.add('deleteTransaction:$id');
    txs.removeWhere((t) => t.id == id);
  }

  @override
  Future<void> renameHolding(String id, String name) async =>
      calls.add('renameHolding:$id:$name');

  @override
  Future<void> deleteHolding(String id) async {
    calls.add('deleteHolding:$id');
    holdingsList.removeWhere((h) => h.id == id);
    txs.removeWhere((t) => t.holdingId == id);
  }
}

class TestHarness {
  TestHarness({AuthSession? signedIn = testUser, List<Kantong>? kantong})
    : auth = FakeAuthRepository(signedIn: signedIn),
      kantong = FakeKantongRepository(kantong);

  final FakeAuthRepository auth;
  final FakeProfileRepository profile = FakeProfileRepository();
  final FakeKantongRepository kantong;
  final FakeFinanceRepository finance = FakeFinanceRepository();

  Widget app() => ProviderScope(
    retry: (_, _) => null,
    overrides: [
      supabaseConfiguredProvider.overrideWithValue(true),
      authRepositoryProvider.overrideWithValue(auth),
      profileRepositoryProvider.overrideWithValue(profile),
      kantongRepositoryProvider.overrideWithValue(kantong),
      financeRepositoryProvider.overrideWithValue(finance),
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
