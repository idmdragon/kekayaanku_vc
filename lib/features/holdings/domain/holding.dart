import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

import '../../../core/supabase/json_decimal.dart';

/// System-defined asset kinds (PRD 5). Slice 2 records rupiah savings and
/// kantong cash; the rest arrive with their slices.
enum HoldingCategory {
  gold('Emas fisik'),
  crypto('Kripto'),
  stock('Saham IDX'),
  mutualFund('Reksadana'),
  deposit('Deposito'),
  savingsIdr('Uang rupiah'),
  savingsFx('Valas'),
  receivable('Piutang'),
  debt('Utang'),
  cash('Kas kantong');

  const HoldingCategory(this.label);
  final String label;

  static HoldingCategory fromDb(String v) => switch (v) {
    'mutual_fund' => mutualFund,
    'savings_idr' => savingsIdr,
    'savings_fx' => savingsFx,
    _ => values.byName(v),
  };
}

/// Rekening or tunai: only a label (PRD 6.2.6).
enum SavingsForm {
  rekening('Rekening'),
  tunai('Tunai');

  const SavingsForm(this.label);
  final String label;
}

/// One tracked position with its current quantity from `holding_positions`.
@immutable
class Holding {
  const Holding({
    required this.id,
    required this.portfolioId,
    required this.category,
    required this.name,
    required this.qty,
    required this.startedOn,
    this.form,
  });

  factory Holding.fromJson(Map<String, dynamic> j) {
    final params = (j['params'] as Map?)?.cast<String, dynamic>() ?? const {};
    final pos = j['holding_positions'];
    final posRow = pos is List ? (pos.isEmpty ? null : pos.first) : pos;
    final form = params['form'] as String?;
    return Holding(
      id: j['id'] as String,
      portfolioId: j['portfolio_id'] as String,
      category: HoldingCategory.fromDb(j['category'] as String),
      name: j['name'] as String,
      qty: decimalOf((posRow as Map?)?['qty']),
      startedOn: dateOf(j['started_on']),
      form: form == null ? null : SavingsForm.values.byName(form),
    );
  }

  /// PostgREST select; numeric columns are cast to text (see json_decimal).
  static const columns =
      'id, portfolio_id, category, name, params, started_on, '
      'holding_positions(qty::text)';

  final String id;
  final String portfolioId;
  final HoldingCategory category;
  final String name;

  /// Balance in rupiah for savings and cash.
  final Decimal qty;
  final DateTime startedOn;
  final SavingsForm? form;

  bool get isCash => category == HoldingCategory.cash;
}
