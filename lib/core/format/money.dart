import 'package:decimal/decimal.dart';

/// Display formatting for id-ID (docs/design-system.md 3).
/// Values are computed in SQL; Dart only rounds for display.

const String kMinus = '−';

final Decimal _million = Decimal.fromInt(1000000);
final Decimal _billion = Decimal.fromInt(1000000000);

String _group(String digits) {
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write('.');
    out.write(digits[i]);
  }
  return out.toString();
}

String _fixed(Decimal abs, int decimals) {
  final parts = abs.toStringAsFixed(decimals).split('.');
  final whole = _group(parts.first);
  return decimals == 0 ? whole : '$whole,${parts[1]}';
}

String _sign(Decimal v, {bool plus = false}) {
  if (v < Decimal.zero) return kMinus;
  if (plus && v > Decimal.zero) return '+';
  return '';
}

/// `Rp731.812.400`, `−Rp64.000.000`.
String formatRupiah(Decimal v) => '${_sign(v)}Rp${_fixed(v.abs(), 0)}';

/// `34.600.000`, `108,40`, `+4.300.000` with [signed].
String formatNumber(Decimal v, {int decimals = 0, bool signed = false}) =>
    '${_sign(v, plus: signed)}${_fixed(v.abs(), decimals)}';

/// Card summaries: `312,41 jt`, `1,23 M`.
String formatCompact(Decimal v, {int decimals = 1, bool signed = false}) {
  final abs = v.abs();
  final String body;
  if (abs >= _billion) {
    body =
        '${_fixed((abs / _billion).toDecimal(scaleOnInfinitePrecision: 6), 2)} M';
  } else {
    body =
        '${_fixed((abs / _million).toDecimal(scaleOnInfinitePrecision: 6), decimals)} jt';
  }
  return '${_sign(v, plus: signed)}$body';
}

/// `+0,44%`, `−9,70%`. [percent] is already in percent units.
String formatPercent(Decimal percent, {int decimals = 2, bool signed = true}) =>
    '${_sign(percent, plus: signed)}${_fixed(percent.abs(), decimals)}%';
