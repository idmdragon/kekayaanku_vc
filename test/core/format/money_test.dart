import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kekayaanku/core/format/money.dart';

Decimal d(String s) => Decimal.parse(s);

void main() {
  group('formatRupiah', () {
    test('groups thousands with dots', () {
      expect(formatRupiah(d('731812400')), 'Rp731.812.400');
      expect(formatRupiah(d('0')), 'Rp0');
      expect(formatRupiah(d('999')), 'Rp999');
      expect(formatRupiah(d('1000')), 'Rp1.000');
    });
    test('uses the minus sign U+2212, not a hyphen', () {
      expect(formatRupiah(d('-64000000')), '−Rp64.000.000');
    });
    test('rounds for display only', () {
      expect(formatRupiah(d('1037712.6')), 'Rp1.037.713');
    });
  });

  group('formatNumber', () {
    test('decimals use a comma', () {
      expect(formatNumber(d('108.4'), decimals: 2), '108,40');
      expect(formatNumber(d('16420')), '16.420');
    });
    test('signed values', () {
      expect(formatNumber(d('4300000'), signed: true), '+4.300.000');
      expect(formatNumber(d('-1760000'), signed: true), '−1.760.000');
      expect(formatNumber(d('0'), signed: true), '0');
    });
  });

  group('formatCompact', () {
    test('millions as jt', () {
      expect(formatCompact(d('312410000'), decimals: 2), '312,41 jt');
      expect(formatCompact(d('2090000')), '2,1 jt');
    });
    test('billions as M', () {
      expect(formatCompact(d('1234500000')), '1,23 M');
    });
    test('signed', () {
      expect(formatCompact(d('-3400000'), signed: true), '−3,4 jt');
    });
  });

  group('formatPercent', () {
    test('signs and comma', () {
      expect(formatPercent(d('0.44')), '+0,44%');
      expect(formatPercent(d('-9.7')), '−9,70%');
      expect(formatPercent(d('0')), '0,00%');
    });
  });
}
