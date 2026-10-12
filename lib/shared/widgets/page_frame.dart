import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// Scrollable page body with the screen gutter and a centred max width,
/// so web layouts do not stretch a phone layout (docs/design-system.md 7).
class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.children,
    this.maxWidth = AppLayout.contentMaxWidth,
    this.header,
    this.bottom,
  });

  final List<Widget> children;
  final double maxWidth;

  /// Pinned above the scroll area (top bar).
  final Widget? header;

  /// Pinned below the scroll area (primary action).
  final Widget? bottom;

  static double gutterFor(double width) => width >= AppBreakpoints.expanded
      ? AppSpacing.gutterWeb
      : AppSpacing.gutterMobile;

  @override
  Widget build(BuildContext context) {
    final gutter = gutterFor(MediaQuery.sizeOf(context).width);
    Widget constrain(Widget child) => Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth + gutter * 2),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          child: child,
        ),
      ),
    );

    return SafeArea(
      bottom: bottom != null,
      child: Column(
        children: [
          if (header != null)
            constrain(
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
                child: header,
              ),
            ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.only(bottom: AppSpacing.s24),
              children: [
                constrain(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (i, child) in children.indexed) ...[
                        if (i > 0) const SizedBox(height: AppSpacing.s12),
                        child,
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (bottom != null)
            constrain(
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
                child: bottom,
              ),
            ),
        ],
      ),
    );
  }
}
