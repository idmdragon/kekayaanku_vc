import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

/// Every top-level screen renders without overflow at phone and desktop
/// widths, in both themes (docs/design-system.md 12 review rule).
void main() {
  final kantong = [
    kantongFixture('a', 'Saham Investing jangka panjang'),
    kantongFixture('b', 'Kripto', emoji: '🪙', order: 1),
    kantongFixture('c', 'Dana Darurat', emoji: '🛟', order: 2),
  ];

  for (final size in [phone, desktop]) {
    for (final dark in [true, false]) {
      final label = '${size.width.toInt()}px ${dark ? 'dark' : 'light'}';

      testWidgets('main screens fit at $label', (t) async {
        setScreen(t, size);
        t.platformDispatcher.platformBrightnessTestValue = dark
            ? Brightness.dark
            : Brightness.light;
        addTearDown(t.platformDispatcher.clearPlatformBrightnessTestValue);

        final h = TestHarness(kantong: kantong);
        await h.profile.fetch('u1');
        h.profile.stored = h.profile.stored!.copyWith(
          themeMode: ThemeMode.system,
        );
        await t.pumpWidget(h.app());
        await t.pumpAndSettle();
        expect(find.text('Overview'), findsOneWidget);
        expect(t.takeException(), isNull);

        for (final tab in ['Kantong', 'Statistik', 'Riwayat']) {
          await t.tap(find.bySemanticsLabel(tab).first);
          await t.pumpAndSettle();
          expect(t.takeException(), isNull, reason: tab);
        }

        await t.tap(find.bySemanticsLabel('Kantong').first);
        await t.pumpAndSettle();
        await t.tap(find.bySemanticsLabel('Tampilan grid'));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull, reason: 'grid');

        await t.tap(find.text('Kripto'));
        await t.pumpAndSettle();
        expect(find.text('Kantong masih kosong'), findsOneWidget);
        expect(t.takeException(), isNull, reason: 'detail');

        await t.tap(find.bySemanticsLabel('Ubah kantong'));
        await t.pumpAndSettle();
        expect(find.text('Simpan perubahan'), findsOneWidget);
        expect(t.takeException(), isNull, reason: 'editor');
      });
    }
  }

  testWidgets('desktop uses the sidebar, phone uses the bottom bar', (t) async {
    setScreen(t, desktop);
    final h = TestHarness();
    await t.pumpWidget(h.app());
    await t.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Tambah'), findsOneWidget);

    setScreen(t, phone);
    await t.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Tambah'), findsNothing);
    expect(find.bySemanticsLabel('Tambah'), findsOneWidget);
  });
}
