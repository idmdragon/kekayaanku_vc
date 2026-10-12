import 'package:flutter/material.dart';

/// Accent the user picks in Profil → Tampilan. Amber is the default (DS-7).
enum AppAccent { amber, lime, blue }

/// One of the eight kantong colours. Used only as a tint, never as text.
enum KantongColor {
  langit(Color(0xFF7FB2FF), 'Langit'),
  aprikot(Color(0xFFF6A85C), 'Aprikot'),
  lavender(Color(0xFFB79CFF), 'Lavender'),
  emas(Color(0xFFE7C35A), 'Emas'),
  mint(Color(0xFF5CC9A7), 'Mint'),
  jambu(Color(0xFFF28AA6), 'Jambu'),
  laut(Color(0xFF8FD0E8), 'Laut'),
  batu(Color(0xFFA9B4C2), 'Batu');

  const KantongColor(this.color, this.label);

  final Color color;
  final String label;
}

/// Role tokens from docs/design-system.md section 2.1.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.fg,
    required this.muted,
    required this.line,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.positive,
    required this.positiveSoft,
    required this.negative,
    required this.warning,
    required this.compare,
    required this.scrim,
  });

  factory AppColors.dark(AppAccent accent) {
    final (a, on) = switch (accent) {
      AppAccent.amber => (const Color(0xFFF0A447), const Color(0xFF1D1306)),
      AppAccent.lime => (const Color(0xFFC8F06A), const Color(0xFF18220A)),
      AppAccent.blue => (const Color(0xFF5AA2FF), const Color(0xFF06162B)),
    };
    const surface = Color(0xFF1A1A1C);
    return AppColors(
      bg: const Color(0xFF0D0D0E),
      surface: surface,
      surface2: const Color(0xFF252528),
      fg: const Color(0xFFF2F2F0),
      muted: const Color(0xFF8E8E93),
      line: const Color(0xFF2B2B2F),
      accent: a,
      onAccent: on,
      accentSoft: Color.alphaBlend(a.withValues(alpha: 0.14), surface),
      positive: const Color(0xFF5CC38F),
      positiveSoft: const Color(0xFF1C2A21),
      negative: const Color(0xFFEF7A6D),
      warning: const Color(0xFFF0B04A),
      compare: accent == AppAccent.blue
          ? const Color(0xFFE7C35A)
          : const Color(0xFF9AA8FF),
      scrim: const Color(0x99000000),
    );
  }

  factory AppColors.light(AppAccent accent) {
    final a = switch (accent) {
      AppAccent.amber => const Color(0xFFA0550A),
      AppAccent.lime => const Color(0xFF4F7A0F),
      AppAccent.blue => const Color(0xFF1F6FD1),
    };
    const surface = Color(0xFFFFFFFF);
    return AppColors(
      bg: const Color(0xFFF6F5F2),
      surface: surface,
      surface2: const Color(0xFFEFEEEA),
      fg: const Color(0xFF18181A),
      muted: const Color(0xFF66666C),
      line: const Color(0xFFE3E1DC),
      accent: a,
      onAccent: const Color(0xFFFFFFFF),
      accentSoft: Color.alphaBlend(a.withValues(alpha: 0.10), surface),
      positive: const Color(0xFF17784A),
      positiveSoft: const Color(0xFFE7F4EC),
      negative: const Color(0xFFB23B2F),
      warning: const Color(0xFF8F5D00),
      compare: accent == AppAccent.blue
          ? const Color(0xFFB7791F)
          : const Color(0xFF4F5FD6),
      scrim: const Color(0x6118181A),
    );
  }

  final Color bg;
  final Color surface;
  final Color surface2;
  final Color fg;
  final Color muted;
  final Color line;
  final Color accent;
  final Color onAccent;
  final Color accentSoft;
  final Color positive;
  final Color positiveSoft;
  final Color negative;
  final Color warning;
  final Color compare;
  final Color scrim;

  /// Kantong tint over [surface]: 16% for cards, 30% for the emoji box.
  Color kantongTint(KantongColor k, {double amount = 0.16}) =>
      Color.alphaBlend(k.color.withValues(alpha: amount), surface);

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(AppColors? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
