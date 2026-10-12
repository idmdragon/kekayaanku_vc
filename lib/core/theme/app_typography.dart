import 'package:flutter/material.dart';

const String kFontFamily = 'Geist';

TextStyle _geist(
  double size,
  double height,
  FontWeight weight, {
  double letterSpacing = 0,
}) {
  return TextStyle(
    fontFamily: kFontFamily,
    fontSize: size,
    height: height / size,
    fontWeight: weight,
    // Geist ships as a variable font; the wght axis must be set explicitly.
    fontVariations: [FontVariation.weight(weight.value.toDouble())],
    letterSpacing: letterSpacing,
  );
}

/// Type scale from docs/design-system.md section 3.
TextTheme buildTextTheme(Color fg, Color muted) {
  return TextTheme(
    displayLarge: _geist(36, 40, FontWeight.w600, letterSpacing: -1.08),
    headlineMedium: _geist(30, 34, FontWeight.w600, letterSpacing: -0.6),
    titleLarge: _geist(17, 22, FontWeight.w600),
    titleMedium: _geist(15, 20, FontWeight.w600),
    bodyMedium: _geist(14, 20, FontWeight.w400),
    bodySmall: _geist(13, 18, FontWeight.w400).copyWith(color: muted),
    labelMedium: _geist(12, 16, FontWeight.w500).copyWith(color: muted),
  ).apply(bodyColor: fg, displayColor: fg);
}

/// Number styles: same family, tabular figures so columns line up.
@immutable
class AppNumberStyles extends ThemeExtension<AppNumberStyles> {
  const AppNumberStyles({
    required this.numLg,
    required this.num,
    required this.numSm,
  });

  factory AppNumberStyles.of(Color fg) {
    const tabular = [FontFeature.tabularFigures()];
    return AppNumberStyles(
      numLg: _geist(
        17,
        22,
        FontWeight.w600,
      ).copyWith(color: fg, fontFeatures: tabular),
      num: _geist(
        14,
        20,
        FontWeight.w500,
      ).copyWith(color: fg, fontFeatures: tabular),
      numSm: _geist(
        12,
        16,
        FontWeight.w500,
      ).copyWith(color: fg, fontFeatures: tabular),
    );
  }

  final TextStyle numLg;
  final TextStyle num;
  final TextStyle numSm;

  @override
  AppNumberStyles copyWith() => this;

  @override
  AppNumberStyles lerp(AppNumberStyles? other, double t) =>
      other == null || t < 0.5 ? this : other;
}
