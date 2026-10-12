import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

import '../../../core/supabase/json_decimal.dart';

enum TxType { opening, deposit, withdraw, adjust, other }

/// How a row relates to capital (HLD 6.2, PRD 7.7).
enum FlowKind { externalIn, externalOut, internal, income, expense, none }

/// A transaction on a rupiah holding, as shown in lists.
@immutable
class CashTransaction {
  const CashTransaction({
    required this.id,
    required this.holdingId,
    required this.holdingName,
    required this.date,
    required this.type,
    required this.qty,
    required this.amount,
    required this.flowKind,
    required this.counted,
    this.note,
  });

  factory CashTransaction.fromJson(Map<String, dynamic> j) {
    final h = (j['holdings'] as Map?)?.cast<String, dynamic>();
    return CashTransaction(
      id: j['id'] as String,
      holdingId: j['holding_id'] as String,
      holdingName: h?['name'] as String? ?? '',
      date: dateOf(j['tx_date']),
      type: switch (j['type'] as String) {
        'opening' => TxType.opening,
        'deposit' => TxType.deposit,
        'withdraw' => TxType.withdraw,
        'adjust' => TxType.adjust,
        _ => TxType.other,
      },
      qty: decimalOf(j['qty']),
      amount: decimalOf(j['amount']),
      flowKind: switch (j['flow_kind'] as String) {
        'external_in' => FlowKind.externalIn,
        'external_out' => FlowKind.externalOut,
        'internal' => FlowKind.internal,
        'income' => FlowKind.income,
        'expense' => FlowKind.expense,
        _ => FlowKind.none,
      },
      counted: j['counted_on'] != null,
      note: j['note'] as String?,
    );
  }

  static const columns =
      'id, holding_id, tx_date, type, qty::text, amount::text, flow_kind, '
      'counted_on, note, created_at, holdings!inner(name, portfolio_id)';

  final String id;
  final String holdingId;
  final String holdingName;
  final DateTime date;
  final TxType type;

  /// Signed for `adjust`, positive otherwise.
  final Decimal qty;
  final Decimal amount;
  final FlowKind flowKind;

  /// Already part of a snapshot; edits become corrections (HLD H-2).
  final bool counted;
  final String? note;

  /// Effect on the balance, for display.
  Decimal get signedAmount => switch (type) {
    TxType.withdraw => -amount,
    TxType.adjust => qty,
    _ => amount,
  };

  String get title => switch (type) {
    TxType.opening => 'Saldo awal',
    TxType.deposit => 'Setor',
    TxType.withdraw => 'Tarik',
    TxType.adjust => switch (flowKind) {
      FlowKind.income => 'Bunga / hasil',
      FlowKind.expense => 'Biaya',
      _ => 'Set saldo',
    },
    TxType.other => 'Transaksi',
  };

  /// What the row means for net deposits, in plain words.
  String get flowLabel => switch (flowKind) {
    FlowKind.externalIn => 'setoran modal',
    FlowKind.externalOut => 'penarikan modal',
    FlowKind.income => 'hasil, masuk performa',
    FlowKind.expense => 'beban, masuk performa',
    FlowKind.none => 'modal awal',
    FlowKind.internal => 'perpindahan internal',
  };
}
