import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'user_avatar.dart';

/// Header row of every screen: avatar (top-level tabs) or back button
/// (child screens), a title, and optional trailing actions.
class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.title,
    this.showBack = false,
    this.showAvatar = false,
    this.actions = const [],
  });

  final String title;
  final bool showBack;
  final bool showAvatar;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= AppBreakpoints.expanded;
    return Row(
      children: [
        if (showBack) ...[
          CircleIconButton(
            icon: AppIcons.back,
            label: 'Kembali',
            onPressed: () => context.canPop() ? context.pop() : context.go('/'),
          ),
          const SizedBox(width: AppSpacing.s12),
        ] else if (showAvatar && !wide) ...[
          const UserAvatar.button(),
          const SizedBox(width: AppSpacing.s12),
        ],
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: context.text.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        for (final a in actions) ...[const SizedBox(width: AppSpacing.s8), a],
      ],
    );
  }
}

/// Round 40 px icon button on `surface`, with a 48 px touch target.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tooltip(
      message: label,
      child: SizedBox.square(
        dimension: kMinTapTarget,
        child: Center(
          child: Material(
            color: c.surface,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: SizedBox.square(
                dimension: AppLayout.avatar,
                child: Icon(
                  icon,
                  size: AppLayout.iconSize,
                  color: c.fg,
                  semanticLabel: label,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
