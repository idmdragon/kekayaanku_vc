import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kekayaanku/core/theme/app_typography.dart';

void main() {
  test('weight() moves the variable-font axis with fontWeight', () {
    final s = const TextStyle().weight(FontWeight.w700);
    expect(s.fontWeight, FontWeight.w700);
    expect(s.fontVariations, [const FontVariation('wght', 700)]);
  });
}
