/// Spacing scale from docs/design-system.md section 4.
abstract final class AppSpacing {
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s48 = 48;

  static const double gutterMobile = 16;
  static const double gutterWeb = 28;
}

abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double sheet = 26;
  static const double pill = 999;
}

/// Layout breakpoints (compact < 600, medium 600–1024, expanded > 1024).
abstract final class AppBreakpoints {
  static const double medium = 600;
  static const double expanded = 1024;
}

/// Minimum touch target.
const double kMinTapTarget = 48;
