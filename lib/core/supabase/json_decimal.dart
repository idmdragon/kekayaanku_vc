import 'package:decimal/decimal.dart';

/// Parses an amount the database sent as a string (or an integer).
/// Amounts never travel as JSON fractions, so nothing passes through a
/// floating point value on the way in.
Decimal decimalOf(Object? v) =>
    v == null ? Decimal.zero : Decimal.parse(v.toString());

Decimal? decimalOrNull(Object? v) =>
    v == null ? null : Decimal.parse(v.toString());

/// `2026-10-12` → local calendar date (business dates are WIB dates).
DateTime dateOf(Object v) {
  final p = (v as String).split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

DateTime? dateOrNull(Object? v) => v == null ? null : dateOf(v);

/// Calendar date as the database expects it.
String dateParam(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
