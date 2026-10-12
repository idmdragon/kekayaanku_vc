import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// Small upper-case label above a group (`KEUANGAN`, `APLIKASI`).
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.s8),
    child: Semantics(
      header: true,
      child: Text(text.toUpperCase(), style: context.text.labelMedium),
    ),
  );
}

/// Rows on one `surface` panel separated by hairlines.
class ListGroup extends StatelessWidget {
  const ListGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (i, child) in children.indexed) ...[
            if (i > 0) Divider(height: 1, color: c.line),
            child,
          ],
        ],
      ),
    );
  }
}

/// One row: tinted icon, title + subtitle, trailing text, chevron.
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailing;
  final VoidCallback? onTap;
  final bool destructive;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tint = destructive ? c.negative : c.accent;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: kMinTapTarget),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s12),
          child: Row(
            children: [
              Container(
                width: AppLayout.emojiBoxSmall,
                height: AppLayout.emojiBoxSmall,
                decoration: BoxDecoration(
                  color: destructive ? c.surface2 : c.accentSoft,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: tint, size: AppLayout.iconSize),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.text.bodyMedium?.copyWith(
                        color: destructive ? c.negative : c.fg,
                      ),
                    ),
                    if (subtitle != null)
                      Text(subtitle!, style: context.text.bodySmall),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.s8),
                Text(trailing!, style: context.text.bodySmall),
              ],
              if (showChevron && onTap != null) ...[
                const SizedBox(width: AppSpacing.s8),
                Icon(
                  AppIcons.forward,
                  size: AppLayout.iconSizeSmall,
                  color: c.muted,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
