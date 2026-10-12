import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kekayaanku/features/dashboard/domain/summary.dart';

import '../helpers/fakes.dart';

const tall = Size(420, 1400);

SnapshotPoint point(int day, int worth, {int flow = 0, int? change}) =>
    SnapshotPoint(
      date: DateTime(2026, 10, day),
      netWorth: Decimal.fromInt(worth),
      netFlow: Decimal.fromInt(flow),
      netDeposits: Decimal.fromInt(worth - 50000),
      change: change == null ? null : Decimal.fromInt(change),
    );

void main() {
  testWidgets('add rupiah savings from an empty kantong', (t) async {
    setScreen(t, tall);
    final h = TestHarness(kantong: [kantongFixture('a', 'Dana Darurat')]);
    await t.pumpWidget(h.app());
    await t.pumpAndSettle();
    await t.tap(find.bySemanticsLabel('Kantong').first);
    await t.pumpAndSettle();
    await t.tap(find.text('Dana Darurat'));
    await t.pumpAndSettle();
    expect(find.text('Kantong masih kosong'), findsOneWidget);

    await t.tap(find.text('Tambah aset'));
    await t.pumpAndSettle();
    // Kinds that arrive later are visible but not active.
    expect(find.bySemanticsLabel('Saham IDX, segera hadir'), findsOneWidget);
    await t.tap(find.bySemanticsLabel('Uang rupiah'));
    await t.pumpAndSettle();

    await t.tap(find.text('Simpan'));
    await t.pumpAndSettle();
    expect(find.text('Beri nama, mis. BCA.'), findsOneWidget);

    await t.enterText(find.byType(TextFormField).at(0), 'Tabungan BCA');
    await t.enterText(find.byType(TextFormField).at(1), '10000000');
    await t.pump();
    expect(find.text('10.000.000'), findsOneWidget);
    expect(
      find.textContaining('Dicatat sebagai modal awal'),
      findsOneWidget,
      reason: 'before the first snapshot an opening is starting capital',
    );
    await t.tap(find.text('Simpan'));
    await t.pumpAndSettle();

    expect(h.finance.calls, ['createSavings:a:Tabungan BCA:rekening:10000000']);
    expect(find.text('Tabungan BCA'), findsOneWidget);
    expect(find.text('Rp10.000.000'), findsWidgets);
  });

  testWidgets('after the first snapshot an opening is explained as a deposit', (
    t,
  ) async {
    setScreen(t, tall);
    final h = TestHarness(kantong: [kantongFixture('a', 'Dana Darurat')]);
    h.finance.points.add(point(11, 0));
    await t.pumpWidget(h.app());
    await t.pumpAndSettle();
    await t.tap(find.bySemanticsLabel('Tambah').first);
    await t.pumpAndSettle();
    await t.tap(find.bySemanticsLabel('Aset baru'));
    await t.pumpAndSettle();
    await t.tap(find.bySemanticsLabel('Uang rupiah'));
    await t.pumpAndSettle();
    expect(find.textContaining('Dicatat sebagai setoran'), findsOneWidget);
  });

  testWidgets('setor and tarik from the Tambah sheet', (t) async {
    setScreen(t, tall);
    final h = TestHarness(kantong: [kantongFixture('a', 'Utama')]);
    final bca = h.finance.seedSavings('a', 'Tabungan BCA', 1000000);
    await t.pumpWidget(h.app());
    await t.pumpAndSettle();

    await t.tap(find.bySemanticsLabel('Tambah').first);
    await t.pumpAndSettle();
    await t.tap(find.bySemanticsLabel('Setor'));
    await t.pumpAndSettle();
    expect(find.text('Setor atau tarik'), findsOneWidget);

    // Default target is the first kantong's cash.
    await t.enterText(find.byType(TextFormField).first, '2500000');
    await t.pump();
    expect(find.text('Setor Rp2.500.000'), findsOneWidget);
    await t.tap(find.text('Setor Rp2.500.000'));
    await t.pumpAndSettle();
    expect(h.finance.calls.last, 'recordFlow:cash-a:in:2500000');

    // Withdrawing more than the savings balance is caught before saving.
    await t.tap(find.bySemanticsLabel('Tambah').first);
    await t.pumpAndSettle();
    await t.tap(find.bySemanticsLabel('Tarik'));
    await t.pumpAndSettle();
    await t.tap(find.byType(DropdownButtonFormField<String>));
    await t.pumpAndSettle();
    await t.tap(find.textContaining('Tabungan BCA ·').last);
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField).first, '1500000');
    await t.pump();
    await t.tap(find.text('Tarik Rp1.500.000'));
    await t.pumpAndSettle();
    expect(find.text('Melebihi saldo Rp1.000.000.'), findsOneWidget);
    expect(h.finance.calls.where((c) => c.contains(bca)), isEmpty);
  });

  testWidgets('set saldo marked as interest', (t) async {
    setScreen(t, tall);
    final h = TestHarness(kantong: [kantongFixture('a', 'Utama')]);
    final bca = h.finance.seedSavings('a', 'Tabungan BCA', 10000000);
    await t.pumpWidget(h.app());
    await t.pumpAndSettle();
    // The bottom bar comes after Beranda's "Kantong" allocation toggle.
    await t.tap(find.bySemanticsLabel('Kantong').last);
    await t.pumpAndSettle();
    await t.tap(find.text('Utama'));
    await t.pumpAndSettle();
    await t.tap(find.textContaining('Tabungan BCA').first);
    await t.pumpAndSettle();
    expect(find.text('Saldo awal'), findsOneWidget);

    await t.tap(find.bySemanticsLabel('Set saldo'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField).first, '10050000');
    await t.tap(find.text('Selisihnya bunga atau biaya'));
    await t.pump();
    expect(find.textContaining('Naik Rp50.000'), findsOneWidget);
    expect(find.textContaining('bunga atau hasil'), findsOneWidget);
    await t.tap(find.text('Simpan saldo'));
    await t.pumpAndSettle();

    expect(h.finance.calls.last, 'setBalance:$bca:10050000:true');
    expect(find.text('Bunga / hasil'), findsOneWidget);
  });

  testWidgets('overview shows net worth, chart and allocation', (t) async {
    setScreen(t, tall);
    final h = TestHarness(
      kantong: [
        kantongFixture('a', 'Utama'),
        kantongFixture('b', 'Dana Darurat', order: 1),
      ],
    );
    h.finance
      ..seedSavings('a', 'Dompet', 2000000)
      ..seedSavings('b', 'Tabungan BCA', 10000000)
      ..points.addAll([point(11, 12000000, change: 0), point(10, 12000000)])
      ..change = Decimal.fromInt(50000);
    await t.pumpWidget(h.app());
    await t.pumpAndSettle();

    expect(find.text('Rp12.000.000'), findsOneWidget);
    expect(find.textContaining('hari ini'), findsWidgets);
    expect(find.text('Dana disetor bersih'), findsOneWidget);
    expect(find.text('Alokasi'), findsOneWidget);
    expect(find.text('83%'), findsOneWidget);
    expect(find.text('17%'), findsOneWidget);
  });

  testWidgets('overview without assets points to Tambah aset', (t) async {
    final h = TestHarness(kantong: [kantongFixture('a', 'Utama')]);
    await t.pumpWidget(h.app());
    await t.pumpAndSettle();
    expect(find.text('Catat aset pertama Anda'), findsOneWidget);
    expect(find.text('Rp0'), findsOneWidget);
  });

  testWidgets('overview reports a failed calculation and retries', (t) async {
    final h = TestHarness(kantong: [kantongFixture('a', 'Utama')]);
    h.finance.summaryError = Exception('boom');
    await t.pumpWidget(h.app());
    await t.pumpAndSettle();
    expect(find.text('Net worth gagal dihitung.'), findsOneWidget);
    h.finance.summaryError = null;
    await t.tap(find.text('Coba lagi'));
    await t.pumpAndSettle();
    expect(find.text('Catat aset pertama Anda'), findsOneWidget);
  });

  testWidgets('riwayat lists snapshots by month with cashflow notes', (
    t,
  ) async {
    final h = TestHarness();
    h.finance.points.addAll([
      point(12, 17050000, flow: 5000000, change: 0),
      point(11, 12050000, change: 50000),
    ]);
    await t.pumpWidget(h.app());
    await t.pumpAndSettle();
    await t.tap(find.bySemanticsLabel('Riwayat').first);
    await t.pumpAndSettle();
    expect(find.text('OKTOBER 2026'), findsOneWidget);
    expect(find.textContaining('termasuk setor 5,00 jt'), findsOneWidget);
    expect(find.text('+50.000'), findsOneWidget);
  });
}
