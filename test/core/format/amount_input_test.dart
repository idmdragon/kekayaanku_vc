import 'package:decimal/decimal.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kekayaanku/core/format/amount_input.dart';
import 'package:kekayaanku/core/format/date.dart';
import 'package:kekayaanku/core/supabase/json_decimal.dart';
import 'package:kekayaanku/features/dashboard/domain/summary.dart';

TextEditingValue typed(String s) => TextEditingValue(
  text: s,
  selection: TextSelection.collapsed(offset: s.length),
);

void main() {
  test('rupiah input parses whole rupiah', () {
    expect(parseRupiahInput('5.000.000'), Decimal.fromInt(5000000));
    expect(parseRupiahInput('Rp 12'), Decimal.fromInt(12));
    expect(parseRupiahInput(''), isNull);
  });

  test('formatter groups thousands as you type', () {
    const f = RupiahInputFormatter();
    expect(f.formatEditUpdate(typed(''), typed('1234567')).text, '1.234.567');
    expect(f.formatEditUpdate(typed('1.234'), typed('01.2345')).text, '12.345');
    final v = f.formatEditUpdate(typed(''), typed('1000'));
    expect(v.selection.end, v.text.length);
  });

  test('today in WIB, whatever the device zone', () {
    // 18:30 UTC on 12 Oct is already 13 Oct in Jakarta.
    expect(
      todayWib(DateTime.utc(2026, 10, 12, 18, 30)),
      DateTime(2026, 10, 13),
    );
    expect(todayWib(DateTime.utc(2026, 10, 12, 10)), DateTime(2026, 10, 12));
  });

  test('amounts from the database never pass through a double', () {
    expect(
      decimalOf('1004.166666666666666667').toString(),
      '1004.166666666666666667',
    );
    final s = DashboardSummary.fromJson({
      'as_of': '2026-10-12',
      'total_assets': '12650000',
      'total_receivables': '0',
      'total_debts': '0',
      'net_worth': '12650000',
      'net_deposits': '12600000',
      'flow_since': '1100000',
      'change': '0',
      'change_pct': '0.0000',
      'base_date': '2026-01-10',
      'first_snapshot_on': '2026-01-05',
      'categories': [
        {'category': 'savings_idr', 'value': '10650000'},
      ],
      'portfolios': [
        {
          'portfolio_id': 'p1',
          'value': '2600000',
          'cost': '2600000',
          'unrealized': '0',
          'cash': '2000000',
          'asset_count': 1,
          'change': null,
          'change_pct': null,
        },
      ],
    });
    expect(s.netDeposits, Decimal.fromInt(12600000));
    expect(s.baseDate, DateTime(2026, 1, 10));
    expect(s.portfolios['p1']!.cash, Decimal.fromInt(2000000));
    expect(s.portfolios['p1']!.change, isNull);
    expect(s.categories['savings_idr'], Decimal.fromInt(10650000));
    expect(s.hasSnapshot, isTrue);
  });
}
