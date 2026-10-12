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

/// Fixed layout sizes from docs/design-system.md 7.
abstract final class AppLayout {
  static const double formMaxWidth = 400;
  static const double contentMaxWidth = 640;
  static const double wideMaxWidth = 960;
  static const double sidebarWidth = 240;
  static const double sidePanelWidth = 420;
  static const double sheetMaxHeightFactor = 0.88;
  static const double avatar = 40;
  static const double avatarLarge = 68;
  static const double emojiBox = 42;
  static const double emojiBoxSmall = 36;
  static const double addButton = 50;
  static const double iconSize = 20;
  static const double iconSizeSmall = 16;
  static const double heroEmoji = 38;
  static const double skeletonCard = 132;
  static const double skeletonHero = 160;
}

/// Motion (docs/design-system.md 11).
abstract final class AppMotion {
  static const Duration short = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 200);
  static const Duration shimmer = Duration(milliseconds: 1200);
}

/// Only floating elements get a shadow (docs/design-system.md 4).
abstract final class AppElevation {
  static const double floating = 8;
}
