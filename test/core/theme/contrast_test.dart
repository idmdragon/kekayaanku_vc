import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kekayaanku/core/theme/app_colors.dart';

/// WCAG 2.x contrast ratio.
double contrast(Color a, Color b) {
  double lum(Color c) {
    double ch(double v) => v <= 0.03928
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
  }

  final la = lum(a), lb = lum(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  for (final accent in AppAccent.values) {
    for (final entry in {
      'dark': AppColors.dark(accent),
      'light': AppColors.light(accent),
    }.entries) {
      final c = entry.value;
      final name = '${entry.key}/${accent.name}';

      test('$name: text tokens reach 4.5:1 on every surface', () {
        for (final bg in [c.bg, c.surface, c.surface2]) {
          for (final fg in [c.fg, c.muted, c.positive, c.negative, c.warning]) {
            expect(
              contrast(fg, bg),
              greaterThanOrEqualTo(4.5),
              reason:
                  '$name ${fg.toARGB32().toRadixString(16)} on '
                  '${bg.toARGB32().toRadixString(16)}',
            );
          }
        }
      });

      test('$name: text on kantong tints reaches 4.5:1', () {
        for (final k in KantongColor.values) {
          for (final bg in [
            c.kantongTint(k, amount: c.kantongHeroTint),
            c.kantongTint(k, amount: 0.09),
            c.kantongInset(k),
          ]) {
            for (final fg in [c.fg, c.kantongMuted(k)]) {
              expect(
                contrast(fg, bg),
                greaterThanOrEqualTo(4.5),
                reason: '$name ${k.name}',
              );
            }
          }
        }
      });

      test('$name: text on accent reaches 4.5:1', () {
        expect(contrast(c.onAccent, c.accent), greaterThanOrEqualTo(4.5));
      });
    }
  }
}
