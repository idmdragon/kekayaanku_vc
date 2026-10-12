import 'package:flutter/material.dart';

import '../../core/errors/user_message.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// Empty state: a specific message and at most one action
/// (docs/design-system.md 9).
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.emoji,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final String? emoji;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.s24,
        horizontal: AppSpacing.s12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (emoji != null)
            ExcludeSemantics(
              child: Text(
                emoji!,
                style: TextStyle(fontSize: AppLayout.heroEmoji),
              ),
            )
          else if (icon != null)
            Container(
              width: AppLayout.emojiBox,
              height: AppLayout.emojiBox,
              decoration: BoxDecoration(
                color: c.accentSoft,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, color: c.accent, size: AppLayout.iconSize),
            ),
          const SizedBox(height: AppSpacing.s12),
          Text(
            title,
            style: context.text.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            message,
            style: context.text.bodySmall,
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: AppSpacing.s16),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

/// Recoverable error: says what failed and offers a retry.
class ErrorPanel extends StatelessWidget {
  const ErrorPanel({
    super.key,
    required this.what,
    required this.error,
    this.onRetry,
  });

  /// What failed, e.g. "Daftar kantong gagal dimuat."
  final String what;
  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: c.negative),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.s4),
              child: Icon(
                AppIcons.warning,
                color: c.negative,
                size: AppLayout.iconSize,
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(what, style: context.text.titleMedium),
                  const SizedBox(height: AppSpacing.s4),
                  Text(userMessage(error), style: context.text.bodySmall),
                  if (onRetry != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: onRetry,
                        child: const Text('Coba lagi'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Grey block that pulses while content loads. Static when the system asks
/// for reduced motion.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.width,
    required this.height,
    this.radius = AppRadius.lg,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: AppMotion.shimmer,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _ctrl.stop();
    } else if (!_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) => Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(c.surface, c.surface2, _ctrl.value),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      ),
    );
  }
}

/// Wraps a loading area so screen readers announce it once.
class LoadingRegion extends StatelessWidget {
  const LoadingRegion({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Semantics(label: 'Memuat', liveRegion: true, child: child);
}
