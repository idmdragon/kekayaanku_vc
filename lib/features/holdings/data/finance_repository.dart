import 'package:decimal/decimal.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/json_decimal.dart';
import '../../dashboard/domain/summary.dart';
import '../domain/cash_transaction.dart';
import '../domain/holding.dart';

/// Reads and writes for holdings, cashflow and snapshots. Every rule lives
/// in SQL (supabase/migrations/20261013090000_*); this only calls it.
abstract interface class FinanceRepository {
  Future<DashboardSummary> summary();
  Future<List<SnapshotPoint>> history();
  Future<List<Holding>> holdings();
  Future<List<CashTransaction>> transactions({
    String? holdingId,
    String? portfolioId,
  });

  /// Creates rupiah savings with its opening balance. The server decides
  /// whether the opening is starting capital or a deposit (PRD A-14, A-42).
  Future<String> createSavings({
    required String portfolioId,
    required String name,
    required SavingsForm form,
    required Decimal amount,
  });

  /// The kantong's cash holding, created on first use.
  Future<String> cashHolding(String portfolioId);
  Future<void> recordOpening(String holdingId, Decimal amount);
  Future<void> recordFlow(
    String holdingId, {
    required bool inflow,
    required Decimal amount,
    required DateTime date,
    String? note,
  });

  /// Returns false when the balance was already that amount.
  Future<bool> setBalance(
    String holdingId, {
    required Decimal balance,
    required DateTime date,
    required bool asIncome,
    String? note,
  });
  Future<void> updateTransaction(
    String id, {
    required Decimal amount,
    required DateTime date,
    String? note,
  });
  Future<void> deleteTransaction(String id);
  Future<void> renameHolding(String id, String name);
  Future<void> deleteHolding(String id);
}

class SupabaseFinanceRepository implements FinanceRepository {
  SupabaseFinanceRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<DashboardSummary> summary() async {
    final res = await _client.rpc<Map<String, dynamic>>('dashboard_summary');
    return DashboardSummary.fromJson(res);
  }

  @override
  Future<List<SnapshotPoint>> history() async {
    final rows = await _client.rpc<List<dynamic>>('snapshot_history');
    return [
      for (final r in rows)
        SnapshotPoint.fromJson((r as Map).cast<String, dynamic>()),
    ];
  }

  @override
  Future<List<Holding>> holdings() async {
    final rows = await _client
        .from('holdings')
        .select(Holding.columns)
        .order('created_at');
    return rows.map(Holding.fromJson).toList();
  }

  @override
  Future<List<CashTransaction>> transactions({
    String? holdingId,
    String? portfolioId,
  }) async {
    var q = _client.from('transactions').select(CashTransaction.columns);
    if (holdingId != null) q = q.eq('holding_id', holdingId);
    if (portfolioId != null) q = q.eq('holdings.portfolio_id', portfolioId);
    final rows = await q
        .order('tx_date', ascending: false)
        .order('created_at', ascending: false);
    return rows.map(CashTransaction.fromJson).toList();
  }

  @override
  Future<String> createSavings({
    required String portfolioId,
    required String name,
    required SavingsForm form,
    required Decimal amount,
  }) => _client.rpc<String>(
    'create_savings',
    params: {
      'p_portfolio': portfolioId,
      'p_name': name.trim(),
      'p_form': form.name,
      'p_amount': amount.toString(),
    },
  );

  @override
  Future<String> cashHolding(String portfolioId) => _client.rpc<String>(
    'portfolio_cash_holding',
    params: {'p_portfolio': portfolioId},
  );

  @override
  Future<void> recordOpening(String holdingId, Decimal amount) =>
      _client.rpc<void>(
        'record_opening',
        params: {'p_holding': holdingId, 'p_amount': amount.toString()},
      );

  @override
  Future<void> recordFlow(
    String holdingId, {
    required bool inflow,
    required Decimal amount,
    required DateTime date,
    String? note,
  }) => _client.rpc<void>(
    'record_flow',
    params: {
      'p_holding': holdingId,
      'p_direction': inflow ? 'in' : 'out',
      'p_amount': amount.toString(),
      'p_on': dateParam(date),
      'p_note': note,
    },
  );

  @override
  Future<bool> setBalance(
    String holdingId, {
    required Decimal balance,
    required DateTime date,
    required bool asIncome,
    String? note,
  }) async {
    final id = await _client.rpc<String?>(
      'set_balance',
      params: {
        'p_holding': holdingId,
        'p_balance': balance.toString(),
        'p_on': dateParam(date),
        'p_as_income': asIncome,
        'p_note': note,
      },
    );
    return id != null;
  }

  @override
  Future<void> updateTransaction(
    String id, {
    required Decimal amount,
    required DateTime date,
    String? note,
  }) => _client.rpc<void>(
    'update_cash_transaction',
    params: {
      'p_id': id,
      'p_amount': amount.toString(),
      'p_on': dateParam(date),
      'p_note': note,
    },
  );

  @override
  Future<void> deleteTransaction(String id) =>
      _client.from('transactions').delete().eq('id', id);

  @override
  Future<void> renameHolding(String id, String name) =>
      _client.from('holdings').update({'name': name.trim()}).eq('id', id);

  @override
  Future<void> deleteHolding(String id) =>
      _client.from('holdings').delete().eq('id', id);
}
