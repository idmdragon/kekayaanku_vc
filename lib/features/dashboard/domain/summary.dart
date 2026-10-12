import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

import '../../../core/supabase/json_decimal.dart';

/// Live figures for one kantong from `dashboard_summary()`.
@immutable
class PortfolioFigures {
  const PortfolioFigures({
    required this.value,
    required this.cost,
    required this.unrealized,
    required this.cash,
    required this.assetCount,
    this.change,
    this.changePct,
  });

  factory PortfolioFigures.fromJson(Map<String, dynamic> j) => PortfolioFigures(
    value: decimalOf(j['value']),
    cost: decimalOf(j['cost']),
    unrealized: decimalOf(j['unrealized']),
    cash: decimalOf(j['cash']),
    assetCount: j['asset_count'] as int,
    change: decimalOrNull(j['change']),
    changePct: decimalOrNull(j['change_pct']),
  );

  final Decimal value;
  final Decimal cost;
  final Decimal unrealized;
  final Decimal cash;
  final int assetCount;

  /// Change since the last snapshot before today, cashflow left out (A-43).
  /// Null until the kantong appears in a snapshot.
  final Decimal? change;
  final Decimal? changePct;
}

/// Net worth card (PRD F-DASH-1), computed by `dashboard_summary()`.
@immutable
class DashboardSummary {
  const DashboardSummary({
    required this.asOf,
    required this.totalAssets,
    required this.totalReceivables,
    required this.totalDebts,
    required this.netWorth,
    required this.netDeposits,
    required this.flowSince,
    required this.portfolios,
    required this.categories,
    this.change,
    this.changePct,
    this.baseDate,
    this.firstSnapshotOn,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> j) => DashboardSummary(
    asOf: dateOf(j['as_of']),
    totalAssets: decimalOf(j['total_assets']),
    totalReceivables: decimalOf(j['total_receivables']),
    totalDebts: decimalOf(j['total_debts']),
    netWorth: decimalOf(j['net_worth']),
    netDeposits: decimalOf(j['net_deposits']),
    flowSince: decimalOf(j['flow_since']),
    change: decimalOrNull(j['change']),
    changePct: decimalOrNull(j['change_pct']),
    baseDate: dateOrNull(j['base_date']),
    firstSnapshotOn: dateOrNull(j['first_snapshot_on']),
    portfolios: {
      for (final p in (j['portfolios'] as List).cast<Map>())
        p['portfolio_id'] as String: PortfolioFigures.fromJson(
          p.cast<String, dynamic>(),
        ),
    },
    categories: {
      for (final c in (j['categories'] as List? ?? const []).cast<Map>())
        c['category'] as String: decimalOf(c['value']),
    },
  );

  final DateTime asOf;
  final Decimal totalAssets;
  final Decimal totalReceivables;
  final Decimal totalDebts;
  final Decimal netWorth;
  final Decimal netDeposits;

  /// Capital cashflow since [baseDate], left out of [change].
  final Decimal flowSince;
  final Decimal? change;
  final Decimal? changePct;
  final DateTime? baseDate;
  final DateTime? firstSnapshotOn;
  final Map<String, PortfolioFigures> portfolios;

  /// Value per asset kind (`savings_idr`, `cash`, …), largest first.
  final Map<String, Decimal> categories;

  bool get hasSnapshot => firstSnapshotOn != null;
}

/// One row of `snapshot_history()`.
@immutable
class SnapshotPoint {
  const SnapshotPoint({
    required this.date,
    required this.netWorth,
    required this.netFlow,
    required this.netDeposits,
    this.change,
  });

  factory SnapshotPoint.fromJson(Map<String, dynamic> j) => SnapshotPoint(
    date: dateOf(j['snap_date']),
    netWorth: decimalOf(j['net_worth']),
    netFlow: decimalOf(j['net_flow']),
    netDeposits: decimalOf(j['net_deposits']),
    change: decimalOrNull(j['change']),
  );

  final DateTime date;
  final Decimal netWorth;
  final Decimal netFlow;
  final Decimal netDeposits;
  final Decimal? change;
}
