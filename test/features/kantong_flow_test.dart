import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kekayaanku/core/theme/app_colors.dart';
import 'package:kekayaanku/features/portfolios/presentation/kantong_widgets.dart';
import 'package:kekayaanku/features/profile/domain/profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../helpers/fakes.dart';

Future<void> openKantongTab(WidgetTester t) async {
  await t.tap(find.bySemanticsLabel('Kantong').first);
  await t.pumpAndSettle();
}

void main() {
  testWidgets('empty kantong tab explains kantong and offers one action', (
    t,
  ) async {
    final h = TestHarness();
    await t.pumpWidget(h.app());
    await t.pumpAndSettle();
    await openKantongTab(t);

    expect(find.text('Belum ada kantong'), findsOneWidget);
    expect(find.text('Buat kantong pertama'), findsOneWidget);
  });

  testWidgets('loading shows a skeleton, then the list', (t) async {
    final h = TestHarness(kantong: [kantongFixture('a', 'Saham Trading')]);
    h.kantong.listGate = Completer();
    await t.pumpWidget(h.app());
    await t.pump();
    await t.pump();
    // The skeleton pulses forever, so pump instead of settling.
    await t.tap(find.bySemanticsLabel('Kantong').first);
    await t.pump();
    await t.pump();

    expect(find.bySemanticsLabel('Memuat'), findsOneWidget);
    h.kantong.listGate!.complete();
    await t.pump();
    await t.pumpAndSettle();
    expect(find.text('Saham Trading'), findsOneWidget);
  });

  testWidgets('a failed load shows what failed and retries', (t) async {
    final h = TestHarness(kantong: [kantongFixture('a', 'Saham Trading')])
      ..kantong.listError = const PostgrestException(message: 'boom');
    await t.pumpWidget(h.app());
    await t.pumpAndSettle();
    await openKantongTab(t);

    expect(find.text('Daftar kantong gagal dimuat.'), findsOneWidget);
    h.kantong.listError = null;
    await t.tap(find.text('Coba lagi'));
    await t.pumpAndSettle();
    expect(find.text('Saham Trading'), findsOneWidget);
  });

  testWidgets('create a kantong: live preview, validation, then detail', (
    t,
  ) async {
    // Tall phone so the whole form fits above the pinned button.
    setScreen(t, const Size(400, 1400));
    final h = TestHarness();
    await t.pumpWidget(h.app());
    await t.pumpAndSettle();
    await openKantongTab(t);
    await t.tap(find.text('Buat kantong pertama'));
    await t.pumpAndSettle();

    expect(find.text('Kantong baru'), findsOneWidget);
    await t.tap(find.widgetWithText(FilledButton, 'Buat kantong'));
    await t.pumpAndSettle();
    expect(find.text('Beri nama kantong.'), findsOneWidget);

    await t.enterText(find.byType(TextFormField).first, 'Dana Darurat');
    for (final label in ['Emoji 🛟', 'Warna Mint']) {
      await t.ensureVisible(find.bySemanticsLabel(label));
      await t.tap(find.bySemanticsLabel(label));
    }
    await t.pumpAndSettle();
    // Preview follows the form.
    expect(
      find.descendant(
        of: find.byType(KantongCard),
        matching: find.text('Dana Darurat'),
      ),
      findsOneWidget,
    );
    expect(find.text('Warna · Mint'), findsOneWidget);

    await t.ensureVisible(find.widgetWithText(FilledButton, 'Buat kantong'));
    await t.tap(find.widgetWithText(FilledButton, 'Buat kantong'));
    await t.pumpAndSettle();

    final saved = h.kantong.items.single;
    expect(saved.name, 'Dana Darurat');
    expect(saved.emoji, '🛟');
    expect(saved.color, KantongColor.mint);
    expect(find.text('🛟 Dana Darurat'), findsOneWidget);
    expect(find.text('Kantong masih kosong'), findsOneWidget);
  });

  testWidgets('switching to grid is saved to the profile', (t) async {
    final h = TestHarness(
      kantong: [
        kantongFixture('a', 'Saham Trading'),
        kantongFixture('b', 'Kripto', emoji: '🪙', order: 1),
      ],
    );
    await t.pumpWidget(h.app());
    await t.pumpAndSettle();
    await openKantongTab(t);

    await t.tap(find.bySemanticsLabel('Tampilan grid'));
    await t.pumpAndSettle();
    expect(h.profile.stored!.kantongView, KantongView.grid);
    expect(find.text('Kripto'), findsOneWidget);
    expect(find.text('+\nKantong baru'), findsOneWidget);
  });

  testWidgets('archive then delete from the Info tab', (t) async {
    final h = TestHarness(kantong: [kantongFixture('a', 'Saham Trading')]);
    await t.pumpWidget(h.app());
    await t.pumpAndSettle();
    await openKantongTab(t);

    await t.tap(find.text('Saham Trading'));
    await t.pumpAndSettle();
    await t.tap(find.text('Info'));
    await t.pumpAndSettle();

    await t.ensureVisible(find.text('Arsipkan kantong'));
    await t.tap(find.text('Arsipkan kantong'));
    await t.pumpAndSettle();
    expect(h.kantong.items.single.archived, isTrue);
    expect(
      find.text('Kantong ini diarsipkan dan tidak tampil di daftar utama.'),
      findsOneWidget,
    );

    await t.ensureVisible(find.text('Hapus kantong'));
    await t.tap(find.text('Hapus kantong'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(TextButton, 'Hapus'));
    await t.pumpAndSettle();
    expect(h.kantong.items, isEmpty);
    expect(find.text('Belum ada kantong'), findsOneWidget);
  });

  testWidgets('accent choice in Tampilan recolours the app', (t) async {
    final h = TestHarness();
    await t.pumpWidget(h.app());
    await t.pumpAndSettle();
    await t.tap(find.bySemanticsLabel('Buka profil'));
    await t.pumpAndSettle();
    await t.tap(find.text('Tampilan'));
    await t.pumpAndSettle();
    await t.tap(find.text('Biru'));
    await t.pumpAndSettle();

    expect(h.profile.stored!.accent, AppAccent.blue);
    final ctx = t.element(find.text('Biru'));
    expect(
      Theme.of(ctx).extension<AppColors>()!.accent,
      AppColors.dark(AppAccent.blue).accent,
    );
  });
}
