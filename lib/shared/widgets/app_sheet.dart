import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// Opens [builder] as a bottom sheet on phones and tablets, or as a 420 px
/// panel from the right on wide screens (docs/design-system.md 7.3).
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
}) {
  final c = context.colors;
  final wide = MediaQuery.sizeOf(context).width >= AppBreakpoints.expanded;
  final reduceMotion = MediaQuery.disableAnimationsOf(context);

  if (!wide) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: c.surface,
      barrierColor: c.scrim,
      constraints: BoxConstraints(
        maxHeight:
            MediaQuery.sizeOf(context).height * AppLayout.sheetMaxHeightFactor,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      builder: (context) => _SheetBody(title: title, child: builder(context)),
    );
  }

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Tutup',
    barrierColor: c.scrim,
    transitionDuration: reduceMotion ? Duration.zero : AppMotion.medium,
    pageBuilder: (context, _, _) => Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: c.surface,
        elevation: AppElevation.floating,
        child: SizedBox(
          width: AppLayout.sidePanelWidth,
          height: double.infinity,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.s16),
              child: _SheetBody(title: title, child: builder(context)),
            ),
          ),
        ),
      ),
    ),
    transitionBuilder: (context, anim, _, child) => SlideTransition(
      position: Tween(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
      child: child,
    ),
  );
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutterMobile,
        0,
        AppSpacing.gutterMobile,
        AppSpacing.s16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(title, style: context.text.titleLarge),
                ),
              ),
              IconButton(
                tooltip: 'Tutup',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: Icon(AppIcons.close, color: c.fg),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          Flexible(child: SingleChildScrollView(child: child)),
        ],
      ),
    );
  }
}
