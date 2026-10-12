import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kekayaanku/app.dart';

void main() {
  testWidgets('without Supabase config the app shows the setup screen', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: KekayaankuApp()));
    await tester.pumpAndSettle();

    expect(find.text('Kekayaanku'), findsOneWidget);
    expect(find.text('Koneksi Supabase'), findsOneWidget);
    // No dart-defines in tests, so Supabase reads as not configured.
    expect(find.textContaining('Belum dikonfigurasi'), findsOneWidget);
  });

  testWidgets('dark theme renders without overflow at phone width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(const ProviderScope(child: KekayaankuApp()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
