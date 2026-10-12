import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../../core/format/date.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../domain/cash_transaction.dart';
import '../domain/holding.dart';

IconData holdingIcon(HoldingCategory c) => switch (c) {
  HoldingCategory.stock => AppIcons.stock,
  HoldingCategory.crypto => AppIcons.crypto,
  HoldingCategory.gold => AppIcons.gold,
  HoldingCategory.mutualFund => AppIcons.fund,
  HoldingCategory.deposit => AppIcons.deposito,
  HoldingCategory.savingsIdr || HoldingCategory.cash => AppIcons.cash,
  HoldingCategory.savingsFx => AppIcons.forex,
  HoldingCategory.receivable => AppIcons.receivable,
  HoldingCategory.debt => AppIcons.debt,
};

/// Square icon tile used by asset and transaction rows.
class IconTile extends StatelessWidget {
  const IconTile({super.key, required this.icon, this.muted = false});

  final IconData icon;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: AppLayout.emojiBoxSmall,
      height: AppLayout.emojiBoxSmall,
      decoration: BoxDecoration(
        color: muted ? c.surface2 : c.accentSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Icon(
        icon,
        size: AppLayout.iconSize,
        color: muted ? c.muted : c.accent,
      ),
    );
  }
}

/// One asset in a kantong: name, kind and value.
class HoldingRow extends StatelessWidget {
  const HoldingRow({super.key, required this.holding, this.label, this.onTap});

  final Holding holding;

  /// Overrides the holding name, e.g. "Kas kantong".
  final String? label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final h = holding;
    final name = label ?? h.name;
    final kind = h.isCash
        ? 'Rupiah, untuk beli dan hasil jual'
        : [h.category.label, if (h.form != null) h.form!.label].join(' · ');
    return Semantics(
      button: onTap != null,
      label: '$name, ${formatRupiah(h.qty)}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kMinTapTarget),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s12),
            child: Row(
              children: [
                IconTile(icon: holdingIcon(h.category)),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodyMedium?.weight(FontWeight.w600),
                      ),
                      Text(kind, style: context.text.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                Text(formatRupiah(h.qty), style: context.nums.num),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One transaction: what it was, when, what it means for capital, amount.
class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.tx,
    this.showHolding = false,
    this.onTap,
  });

  final CashTransaction tx;
  final bool showHolding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final amount = tx.signedAmount;
    final icon = switch (tx.type) {
      TxType.withdraw => AppIcons.withdraw,
      TxType.adjust => AppIcons.setBalance,
      _ => AppIcons.deposit,
    };
    final meta = [
      formatDateShort(tx.date),
      if (showHolding) tx.holdingName,
      tx.flowLabel,
    ].join(' · ');
    return Semantics(
      button: onTap != null,
      label: '${tx.title}, $meta, ${formatRupiah(amount)}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kMinTapTarget),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s12),
            child: Row(
              children: [
                IconTile(icon: icon, muted: tx.type == TxType.opening),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tx.title, style: context.text.bodyMedium),
                      Text(meta, style: context.text.bodySmall),
                      if (tx.note != null)
                        Text(
                          tx.note!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodySmall,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                Text(
                  '${amount > Decimal.zero ? '+' : ''}${formatRupiah(amount)}',
                  style: context.nums.num.copyWith(
                    color: amount < Decimal.zero ? c.negative : c.fg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Date row for forms: "Hari ini" or the chosen date, opens a picker.
class DateRow extends StatelessWidget {
  const DateRow({
    super.key,
    required this.value,
    required this.onChanged,
    required this.firstDate,
  });

  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final DateTime firstDate;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final today = todayWib();
    final label = isSameDate(value, today)
        ? 'Hari ini, ${formatDateShort(value)}'
        : formatDateShort(value);
    return Material(
      color: c.surface2,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: value,
            firstDate: firstDate.isAfter(today) ? today : firstDate,
            lastDate: today,
            helpText: 'Tanggal transaksi',
          );
          if (picked != null) onChanged(picked);
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kMinTapTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
            child: Row(
              children: [
                Icon(
                  AppIcons.calendar,
                  size: AppLayout.iconSizeSmall,
                  color: c.muted,
                ),
                const SizedBox(width: AppSpacing.s8),
                Expanded(child: Text(label, style: context.text.bodyMedium)),
                Text(
                  'Ubah',
                  style: context.text.bodySmall?.copyWith(color: c.accent),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Muted explanatory line under a form.
class NoteText extends StatelessWidget {
  const NoteText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: context.text.bodySmall);
}
