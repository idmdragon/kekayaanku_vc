import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/date.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/list_group.dart';
import '../../../shared/widgets/page_frame.dart';
import '../../../shared/widgets/states.dart';
import '../../../shared/widgets/top_bar.dart';
import '../../dashboard/domain/summary.dart';
import '../../holdings/application/finance_providers.dart';

/// Riwayat: one row per daily snapshot, grouped by month (PRD 6.6).
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(snapshotHistoryProvider);
    return Scaffold(
      body: PageFrame(
        header: const TopBar(title: 'Riwayat snapshot', showAvatar: true),
        children: async.when(
          skipLoadingOnReload: true,
          loading: () => const [
            LoadingRegion(child: Skeleton(height: AppLayout.skeletonCard)),
          ],
          error: (e, _) => [
            ErrorPanel(
              what: 'Riwayat gagal dimuat.',
              error: e,
              onRetry: () => ref.invalidate(snapshotHistoryProvider),
            ),
          ],
          data: (points) => points.isEmpty
              ? const [
                  EmptyState(
                    icon: AppIcons.history,
                    title: 'Belum ada snapshot',
                    message:
                        'Setiap hari pukul 18.00 WIB kekayaan Anda dicatat '
                        'permanen. Daftar snapshot tampil di sini.',
                  ),
                ]
              : _grouped(points),
        ),
      ),
    );
  }

  List<Widget> _grouped(List<SnapshotPoint> points) {
    final out = <Widget>[
      const _Banner('Snapshot otomatis setiap hari pukul 18.00 WIB'),
    ];
    String? month;
    var rows = <Widget>[];
    void flush() {
      if (rows.isNotEmpty) out.add(ListGroup(children: rows));
      rows = [];
    }

    for (final p in points) {
      final m = formatMonthYear(p.date);
      if (m != month) {
        flush();
        out.add(SectionLabel(m));
        month = m;
      }
      rows.add(_SnapshotRow(point: p));
    }
    flush();
    return out;
  }
}

class _Banner extends StatelessWidget {
  const _Banner(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s8,
        vertical: AppSpacing.s4,
      ),
      decoration: BoxDecoration(
        color: context.colors.surface2,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(text, style: context.text.bodySmall),
    ),
  );
}

class _SnapshotRow extends StatelessWidget {
  const _SnapshotRow({required this.point});

  final SnapshotPoint point;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final p = point;
    final weekend = p.date.weekday >= DateTime.saturday;
    final meta = [
      formatWeekday(p.date),
      if (weekend) 'bursa libur',
      if (p.netFlow > Decimal.zero)
        'termasuk setor ${formatCardAmount(p.netFlow)}'
      else if (p.netFlow < Decimal.zero)
        'termasuk tarik ${formatCardAmount(-p.netFlow)}',
    ].join(' · ');
    final change = p.change;
    return Semantics(
      label:
          '${formatDateShort(p.date)}, net worth ${formatRupiah(p.netWorth)}',
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: kMinTapTarget),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatDayMonth(p.date),
                      style: context.text.bodyMedium,
                    ),
                    Text(meta, style: context.text.bodySmall),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(formatRupiah(p.netWorth), style: context.nums.num),
                  if (change != null)
                    Text(
                      formatNumber(change, signed: true),
                      style: context.nums.numSm.copyWith(
                        color: change > Decimal.zero
                            ? c.positive
                            : change < Decimal.zero
                            ? c.negative
                            : c.muted,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Perlu perhatian: stale prices, maturing deposits, failed snapshots.
class AttentionScreen extends StatelessWidget {
  const AttentionScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: PageFrame(
      header: TopBar(title: 'Perlu perhatian', showBack: true),
      children: [
        EmptyState(
          icon: AppIcons.check,
          title: 'Semua aman',
          message:
              'Tidak ada harga basi, deposito jatuh tempo, atau snapshot '
              'yang gagal.',
        ),
      ],
    ),
  );
}
