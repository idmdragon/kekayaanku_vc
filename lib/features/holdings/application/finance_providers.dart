import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../dashboard/domain/summary.dart';
import '../data/finance_repository.dart';
import '../domain/cash_transaction.dart';
import '../domain/holding.dart';

final financeRepositoryProvider = Provider<FinanceRepository>(
  (ref) => SupabaseFinanceRepository(ref.watch(supabaseClientProvider)),
);

String? _userId(Ref ref) =>
    ref.watch(authControllerProvider.select((s) => s?.userId));

/// Live net worth and per-kantong figures (PRD F-DASH-1).
final dashboardSummaryProvider = FutureProvider<DashboardSummary?>((ref) {
  if (_userId(ref) == null) return null;
  return ref.watch(financeRepositoryProvider).summary();
});

/// Snapshots, newest first.
final snapshotHistoryProvider = FutureProvider<List<SnapshotPoint>>((ref) {
  if (_userId(ref) == null) return const [];
  return ref.watch(financeRepositoryProvider).history();
});

/// Every holding of the user, kantong cash included.
final holdingsProvider = FutureProvider<List<Holding>>((ref) {
  if (_userId(ref) == null) return const [];
  return ref.watch(financeRepositoryProvider).holdings();
});

final holdingByIdProvider = Provider.family<AsyncValue<Holding?>, String>(
  (ref, id) => ref
      .watch(holdingsProvider)
      .whenData((all) => all.where((h) => h.id == id).firstOrNull),
);

final holdingTransactionsProvider =
    FutureProvider.family<List<CashTransaction>, String>((ref, holdingId) {
      _userId(ref);
      return ref
          .watch(financeRepositoryProvider)
          .transactions(holdingId: holdingId);
    });

final kantongTransactionsProvider =
    FutureProvider.family<List<CashTransaction>, String>((ref, portfolioId) {
      _userId(ref);
      return ref
          .watch(financeRepositoryProvider)
          .transactions(portfolioId: portfolioId);
    });

/// Writes, each followed by a reload of everything the change can touch.
class FinanceActions {
  FinanceActions(this._ref);

  final Ref _ref;

  FinanceRepository get _repo => _ref.read(financeRepositoryProvider);

  void refresh() {
    _ref
      ..invalidate(dashboardSummaryProvider)
      ..invalidate(snapshotHistoryProvider)
      ..invalidate(holdingsProvider)
      ..invalidate(holdingTransactionsProvider)
      ..invalidate(kantongTransactionsProvider);
  }

  Future<T> _run<T>(Future<T> Function() write) async {
    try {
      return await write();
    } finally {
      refresh();
    }
  }

  Future<String> createSavings({
    required String portfolioId,
    required String name,
    required SavingsForm form,
    required Decimal amount,
  }) => _run(
    () => _repo.createSavings(
      portfolioId: portfolioId,
      name: name,
      form: form,
      amount: amount,
    ),
  );

  Future<void> openKantongCash(String portfolioId, Decimal amount) =>
      _run(() async {
        final id = await _repo.cashHolding(portfolioId);
        await _repo.recordOpening(id, amount);
      });

  /// Setor or tarik on a holding, or on a kantong's cash when [holdingId]
  /// is null.
  Future<void> recordFlow({
    String? holdingId,
    String? portfolioId,
    required bool inflow,
    required Decimal amount,
    required DateTime date,
    String? note,
  }) => _run(() async {
    final id = holdingId ?? await _repo.cashHolding(portfolioId!);
    await _repo.recordFlow(
      id,
      inflow: inflow,
      amount: amount,
      date: date,
      note: note,
    );
  });

  Future<bool> setBalance(
    String holdingId, {
    required Decimal balance,
    required DateTime date,
    required bool asIncome,
    String? note,
  }) => _run(
    () => _repo.setBalance(
      holdingId,
      balance: balance,
      date: date,
      asIncome: asIncome,
      note: note,
    ),
  );

  Future<void> updateTransaction(
    String id, {
    required Decimal amount,
    required DateTime date,
    String? note,
  }) => _run(
    () => _repo.updateTransaction(id, amount: amount, date: date, note: note),
  );

  Future<void> deleteTransaction(String id) =>
      _run(() => _repo.deleteTransaction(id));

  Future<void> renameHolding(String id, String name) =>
      _run(() => _repo.renameHolding(id, name));

  Future<void> deleteHolding(String id) => _run(() => _repo.deleteHolding(id));
}

final financeActionsProvider = Provider<FinanceActions>(FinanceActions.new);
