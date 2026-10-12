import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../../core/format/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../domain/kantong.dart';

/// Rounded square with the kantong emoji on a 30% tint.
class KantongEmojiBox extends StatelessWidget {
  const KantongEmojiBox({
    super.key,
    required this.emoji,
    required this.color,
    this.size = AppLayout.emojiBox,
  });

  final String emoji;
  final KantongColor color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.kantongTint(color, amount: 0.30),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: ExcludeSemantics(
        child: Text(emoji, style: TextStyle(fontSize: size * 0.48)),
      ),
    );
  }
}

/// Modal · Unrealized · Tunai under the card value (PRD F-PF-9).
class KantongFiguresRow extends StatelessWidget {
  const KantongFiguresRow({super.key, required this.kantong});

  final Kantong kantong;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final f = kantong.figures;
    Widget cell(String label, String value, {Color? color}) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s8,
          vertical: AppSpacing.s8,
        ),
        decoration: BoxDecoration(
          color: c.kantongInset(kantong.color),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: context.text.labelMedium?.copyWith(
                color: c.kantongMuted(kantong.color),
              ),
            ),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.nums.numSm.copyWith(color: color ?? c.fg),
            ),
          ],
        ),
      ),
    );

    return Row(
      children: [
        cell('Modal', formatCardAmount(f.cost)),
        const SizedBox(width: AppSpacing.s8),
        cell(
          'Unrealized',
          formatCardAmount(f.unrealized),
          color: _plColor(c, f.unrealized),
        ),
        const SizedBox(width: AppSpacing.s8),
        cell('Tunai', kantong.cashEnabled ? formatCardAmount(f.cash) : '—'),
      ],
    );
  }
}

/// `+0,82% hari ini`, coloured by direction. Empty before the kantong's
/// first snapshot.
class KantongChangeText extends StatelessWidget {
  const KantongChangeText({super.key, required this.figures});

  final KantongFigures figures;

  @override
  Widget build(BuildContext context) {
    final pct = figures.changePct;
    if (pct == null) return const SizedBox.shrink();
    final c = context.colors;
    return Text(
      '${formatPercent(pct)} hari ini',
      style: context.nums.numSm.copyWith(color: plColor(c, pct)),
    );
  }
}

/// Positive green, negative red, zero in the text colour.
Color plColor(AppColors c, Decimal v) => _plColor(c, v);

Color _plColor(AppColors c, Decimal v) => v > Decimal.zero
    ? c.positive
    : v < Decimal.zero
    ? c.negative
    : c.fg;

String _assetsLine(Kantong k) => k.figures.assetCount == 0
    ? 'Belum ada aset'
    : '${k.figures.assetCount} aset';

/// Full-width card in the list view.
class KantongCard extends StatelessWidget {
  const KantongCard({super.key, required this.kantong, this.onTap});

  final Kantong kantong;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final k = kantong;
    return Semantics(
      button: onTap != null,
      label: 'Kantong ${k.name}',
      child: _CardSurface(
        color: k.color,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                KantongEmojiBox(emoji: k.emoji, color: k.color),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        k.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleMedium,
                      ),
                      Text(
                        _assetsLine(k),
                        style: context.text.bodySmall?.copyWith(
                          color: c.kantongMuted(k.color),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatCardAmount(k.figures.value),
                      style: context.nums.numLg,
                    ),
                    KantongChangeText(figures: k.figures),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s12),
            KantongFiguresRow(kantong: k),
          ],
        ),
      ),
    );
  }
}

/// Compact card in the grid view.
class KantongGridCard extends StatelessWidget {
  const KantongGridCard({super.key, required this.kantong, this.onTap});

  final Kantong kantong;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final k = kantong;
    final f = k.figures;
    Widget line(String label, String value, {Color? color}) => Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: context.text.labelMedium?.copyWith(
              color: c.kantongMuted(k.color),
            ),
          ),
        ),
        Text(value, style: context.nums.numSm.copyWith(color: color ?? c.fg)),
      ],
    );

    return Semantics(
      button: onTap != null,
      label: 'Kantong ${k.name}',
      child: _CardSurface(
        color: k.color,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            KantongEmojiBox(
              emoji: k.emoji,
              color: k.color,
              size: AppLayout.emojiBoxSmall,
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              k.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.titleMedium,
            ),
            Text(
              _assetsLine(k),
              style: context.text.bodySmall?.copyWith(
                color: c.kantongMuted(k.color),
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(formatCardAmount(f.value), style: context.nums.numLg),
            KantongChangeText(figures: f),
            const SizedBox(height: AppSpacing.s8),
            Divider(height: 1, color: c.kantongTint(k.color, amount: 0.5)),
            const SizedBox(height: AppSpacing.s8),
            line('Modal', formatCardAmount(f.cost)),
            line(
              'Unrealized',
              formatCardAmount(f.unrealized),
              color: _plColor(c, f.unrealized),
            ),
            line('Tunai', k.cashEnabled ? formatCardAmount(f.cash) : '—'),
          ],
        ),
      ),
    );
  }
}

class _CardSurface extends StatelessWidget {
  const _CardSurface({required this.color, required this.child, this.onTap});

  final KantongColor color;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final radius = BorderRadius.circular(AppRadius.xl);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: c.kantongGradient(color),
        borderRadius: radius,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s12),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Dashed "+ Kantong baru" tile.
class NewKantongTile extends StatelessWidget {
  const NewKantongTile({super.key, required this.onTap, this.label});

  final VoidCallback onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      child: CustomPaint(
        painter: _DashedBorderPainter(color: c.line, radius: AppRadius.xl),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: kMinTapTarget),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s16),
                child: Center(
                  child: Text(
                    label ?? '+ Buat kantong baru',
                    textAlign: TextAlign.center,
                    style: context.text.bodyMedium?.copyWith(color: c.muted),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const double _dash = 6;
  static const double _gap = 4;
  static const double _stroke = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(_stroke / 2),
      Radius.circular(radius),
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke;
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += _dash + _gap) {
        canvas.drawPath(metric.extractPath(d, d + _dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
