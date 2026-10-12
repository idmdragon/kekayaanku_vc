import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

enum KantongView { list, grid }

/// Row of `public.profiles`.
@immutable
class Profile {
  const Profile({
    required this.userId,
    required this.displayName,
    required this.accent,
    required this.themeMode,
    required this.kantongView,
    required this.trackingStartedOn,
  });

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
    userId: j['user_id'] as String,
    displayName: j['display_name'] as String? ?? '',
    accent: AppAccent.values.byName(j['accent'] as String? ?? 'amber'),
    themeMode: ThemeMode.values.byName(j['theme_mode'] as String? ?? 'system'),
    kantongView: KantongView.values.byName(
      j['kantong_view'] as String? ?? 'list',
    ),
    trackingStartedOn: DateTime.parse(j['tracking_started_on'] as String),
  );

  final String userId;
  final String displayName;
  final AppAccent accent;
  final ThemeMode themeMode;
  final KantongView kantongView;
  final DateTime trackingStartedOn;

  Profile copyWith({
    String? displayName,
    AppAccent? accent,
    ThemeMode? themeMode,
    KantongView? kantongView,
  }) => Profile(
    userId: userId,
    displayName: displayName ?? this.displayName,
    accent: accent ?? this.accent,
    themeMode: themeMode ?? this.themeMode,
    kantongView: kantongView ?? this.kantongView,
    trackingStartedOn: trackingStartedOn,
  );

  /// Columns the client may write (see the column grants in the migration).
  Map<String, dynamic> toUpdateJson() => {
    'display_name': displayName,
    'accent': accent.name,
    'theme_mode': themeMode.name,
    'kantong_view': kantongView.name,
  };
}
