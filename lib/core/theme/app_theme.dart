import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Builds ThemeData for one brightness from the design tokens.
ThemeData buildAppTheme(Brightness brightness, AppAccent accent) {
  final c = brightness == Brightness.dark
      ? AppColors.dark(accent)
      : AppColors.light(accent);
  final text = buildTextTheme(c.fg, c.muted);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: kFontFamily,
    scaffoldBackgroundColor: c.bg,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: c.accent,
      onPrimary: c.onAccent,
      secondary: c.accent,
      onSecondary: c.onAccent,
      error: c.negative,
      onError: c.bg,
      surface: c.surface,
      onSurface: c.fg,
      surfaceContainerHighest: c.surface2,
      outline: c.line,
    ),
    textTheme: text,
    dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.accent,
        foregroundColor: c.onAccent,
        minimumSize: const Size.fromHeight(kMinTapTarget),
        shape: const StadiumBorder(),
        textStyle: text.titleMedium,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface2,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: BorderSide(color: c.accent, width: 1.5),
      ),
      labelStyle: text.labelMedium,
    ),
    extensions: [c, AppNumberStyles.of(c.fg)],
  );
}
