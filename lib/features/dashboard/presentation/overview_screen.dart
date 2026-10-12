import 'package:decimal/decimal.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/date.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/page_frame.dart';
import '../../../shared/widgets/states.dart';
import '../../../shared/widgets/top_bar.dart';
import '../../holdings/application/finance_providers.dart';
import '../../holdings/domain/holding.dart';
import '../../portfolios/application/kantong_controller.dart';
import '../../portfolios/domain/kantong.dart';
import '../domain/summary.dart';

/// Beranda "Overview" (PRD F-DASH-1..5, docs/design-system.md 7.1):
/// net worth card, net worth chart from snapshots, allocation donut.
/// Benchmarks and ranges arrive with slice 7.
class OverviewScreen extends ConsumerWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dashboardSummaryProvider);
    final kantong = ref.watch(kantongListProvider);

    void retry() {
      ref.invalidate(dashboardSummaryProvider);
      ref.invalidate(snapshotHistoryProvider);
      ref.invalidate(kantongControllerProvider);
    }

    final List<Widget> body;
    if (summary.hasError && !summary.hasValue) {
      body = [
        ErrorPanel(
          what: 'Net worth gagal dihitung.',
          error: summary.error!,
          onRetry: retry,
        ),
      ];
    } else if (kantong.hasError && !kantong.hasValue) {
      body = [
        ErrorPanel(
          what: 'Kantong gagal dimuat.',
          error: kantong.error!,
          onRetry: retry,
        ),
      ];
    } else if (!summary.hasValue || !kantong.hasValue) {
      body = const [
        LoadingRegion(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Skeleton(height: AppLayout.skeletonHero, radius: AppRadius.xl),
              SizedBox(height: AppSpacing.s12),
              Skeleton(height: AppLayout.chartHeight, radius: AppRadius.xl),
            ],
          ),
        ),
      ];
    } else {
      final s = summary.value!;
      final list = kantong.value!.where((k) => !k.archived).toList();
      final empty = s.totalAssets == Decimal.zero && s.categories.isEmpty;
      body = [_Content(summary: s, kantong: list, empty: empty)];
    }

    return Scaffold(
      body: PageFrame(
        maxWidth: AppLayout.wideMaxWidth,
        header: TopBar(
          title: 'Overview',
          showAvatar: true,
          actions: [
            CircleIconButton(
              icon: AppIcons.attention,
              label: 'Perlu perhatian',
              onPressed: () => context.push('/perhatian'),
            ),
          ],
        ),
        children: body,
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.summary,
    required this.kantong,
    required this.empty,
  });

  final DashboardSummary summary;
  final List<Kantong> kantong;
  final bool empty;

  @override
  Widget build(BuildContext context) {
    final hero = _NetWorthHero(summary: summary, kantongCount: kantong.length);
    final chart = _ChartCard(summary: summary);
    final emptyState = EmptyState(
      icon: AppIcons.wallet,
      title: 'Catat aset pertama Anda',
      message:
          'Tambahkan tabungan atau saldo kas kantong. Net worth dan grafik '
          'terisi dari situ, dengan snapshot setiap hari pukul 18.00 WIB.',
      actionLabel: 'Tambah aset',
      onAction: () => context.push('/aset/baru'),
    );
    final alloc = _AllocationCard(summary: summary, kantong: kantong);

    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth >= AppLayout.twoColumnMin) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    hero,
                    const SizedBox(height: AppSpacing.s12),
                    if (empty) emptyState else chart,
                  ],
                ),
              ),
              if (!empty) ...[
                const SizedBox(width: AppSpacing.s16),
                Expanded(flex: 2, child: alloc),
              ],
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            hero,
            const SizedBox(height: AppSpacing.s12),
            if (empty)
              emptyState
            else ...[
              chart,
              const SizedBox(height: AppSpacing.s12),
              alloc,
            ],
          ],
        );
      },
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, {this.tone});

  final String text;

  /// Positive, negative or null for neutral.
  final bool? tone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = switch (tone) {
      true => c.positive,
      false => c.negative,
      null => c.muted,
    };
    final bg = switch (tone) {
      true => c.positiveSoft,
      false => Color.alphaBlend(c.negative.withValues(alpha: 0.14), c.surface),
      null => c.surface2,
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s8,
        vertical: AppSpacing.s4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(text, style: context.nums.numSm.copyWith(color: fg)),
    );
  }
}

class _NetWorthHero extends StatelessWidget {
  const _NetWorthHero({required this.summary, required this.kantongCount});

  final DashboardSummary summary;
  final int kantongCount;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = summary;
    final change = s.change;
    final up = change == null ? null : change >= Decimal.zero;
    final String note;
    if (!s.hasSnapshot) {
      note =
          'Snapshot pertama tercatat hari ini pukul 18.00 WIB. Perubahan '
          'harian tampil mulai besok.';
    } else if (s.flowSince != Decimal.zero) {
      note =
          'Perubahan tidak termasuk '
          '${s.flowSince > Decimal.zero ? 'setoran' : 'penarikan'} '
          '${formatRupiah(s.flowSince.abs())} sejak snapshot '
          '${formatDayMonth(s.baseDate ?? s.asOf)}.';
    } else {
      note =
          'Dibanding snapshot ${formatDayMonth(s.baseDate ?? s.asOf)}, '
          '18.00 WIB.';
    }

    return Semantics(
      container: true,
      label: 'Net worth ${formatRupiah(s.netWorth)}',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [c.surface2, c.surface],
          ),
          border: Border.all(color: c.line),
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Net worth · ${formatDateShort(s.asOf)}',
                    style: context.text.bodySmall,
                  ),
                ),
                Text('$kantongCount kantong', style: context.text.bodySmall),
              ],
            ),
            const SizedBox(height: AppSpacing.s4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatRupiah(s.netWorth),
                style: context.text.displayLarge?.copyWith(
                  fontFeatures: context.nums.num.fontFeatures,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
            Wrap(
              spacing: AppSpacing.s8,
              runSpacing: AppSpacing.s4,
              children: [
                if (change != null)
                  _Pill(
                    '${up! ? '▲' : '▼'} ${formatCardAmount(change.abs())}'
                    '${s.changePct == null ? '' : ' (${formatPercent(s.changePct!)})'}'
                    ' hari ini',
                    tone: change == Decimal.zero ? null : up,
                  ),
                _Pill('Disetor bersih ${formatCardAmount(s.netDeposits)}'),
              ],
            ),
            const SizedBox(height: AppSpacing.s12),
            Divider(height: 1, color: c.line),
            const SizedBox(height: AppSpacing.s8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Aset ${formatCardAmount(s.totalAssets)} · Piutang '
                    '${formatCardAmount(s.totalReceivables)}',
                    style: context.nums.numSm.copyWith(color: c.muted),
                  ),
                ),
                Text(
                  'Utang ${formatCardAmount(-s.totalDebts)}',
                  style: context.nums.numSm.copyWith(
                    color: s.totalDebts == Decimal.zero ? c.muted : c.negative,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(note, style: context.text.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _ChartCard extends ConsumerWidget {
  const _ChartCard({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final history = ref.watch(snapshotHistoryProvider);
    final Widget inner = history.when(
      skipLoadingOnReload: true,
      loading: () =>
          const LoadingRegion(child: Skeleton(height: AppLayout.chartHeight)),
      error: (e, _) => ErrorPanel(
        what: 'Grafik gagal dimuat.',
        error: e,
        onRetry: () => ref.invalidate(snapshotHistoryProvider),
      ),
      data: (points) => points.length < 2
          ? _ChartEmpty(count: points.length)
          : _NetWorthChart(points: points.reversed.toList()),
    );
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Net worth harian', style: context.text.titleMedium),
          const SizedBox(height: AppSpacing.s8),
          inner,
        ],
      ),
    );
  }
}

class _ChartEmpty extends StatelessWidget {
  const _ChartEmpty({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: AppLayout.chartHeight,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.chart, color: context.colors.muted),
          const SizedBox(height: AppSpacing.s8),
          Text(
            count == 0
                ? 'Grafik terisi dari snapshot harian pukul 18.00 WIB.'
                : 'Satu snapshot tercatat. Garis muncul setelah snapshot '
                      'kedua besok.',
            textAlign: TextAlign.center,
            style: context.text.bodySmall,
          ),
        ],
      ),
    ),
  );
}

class _NetWorthChart extends StatelessWidget {
  const _NetWorthChart({required this.points});

  /// Oldest first.
  final List<SnapshotPoint> points;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Chart coordinates only; amounts stay Decimal everywhere else.
    List<FlSpot> spots(Decimal Function(SnapshotPoint) pick) => [
      for (final (i, p) in points.indexed)
        FlSpot(i.toDouble(), pick(p).toDouble()),
    ];
    final worth = spots((p) => p.netWorth);
    final deposits = spots((p) => p.netDeposits);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: AppLayout.chartHeight,
          child: Semantics(
            label:
                'Grafik net worth dari ${formatDateShort(points.first.date)} '
                'sampai ${formatDateShort(points.last.date)}',
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: c.line,
                    strokeWidth: 1,
                    dashArray: const [2, 3],
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  leftTitles: const AxisTitles(),
                  bottomTitles: const AxisTitles(),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: AppLayout.chartAxisWidth,
                      getTitlesWidget: (v, meta) => SideTitleWidget(
                        meta: meta,
                        child: Text(
                          formatCompact(
                            Decimal.parse(v.round().toString()),
                            decimals: 0,
                          ),
                          style: context.text.labelSmall,
                        ),
                      ),
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => c.surface2,
                    getTooltipItems: (spots) => [
                      for (final s in spots)
                        LineTooltipItem(
                          s.barIndex == 0
                              ? '${formatDayMonth(points[s.x.toInt()].date)}\n'
                                    'Net worth ${formatRupiah(points[s.x.toInt()].netWorth)}'
                              : 'Disetor bersih '
                                    '${formatRupiah(points[s.x.toInt()].netDeposits)}',
                          context.nums.numSm.copyWith(color: c.fg),
                        ),
                    ],
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: worth,
                    color: c.accent,
                    barWidth: 2,
                    isCurved: false,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          c.accent.withValues(alpha: 0.28),
                          c.accent.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                  LineChartBarData(
                    spots: deposits,
                    color: c.muted,
                    barWidth: 1.4,
                    dashArray: const [4, 3],
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
              duration: AppMotion.short,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        Wrap(
          spacing: AppSpacing.s16,
          children: [
            _Legend(color: c.accent, label: 'Net worth'),
            _Legend(color: c.muted, label: 'Dana disetor bersih'),
          ],
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: AppSpacing.s12, height: AppSpacing.s4 / 2, color: color),
      const SizedBox(width: AppSpacing.s4),
      Text(label, style: context.text.labelMedium),
    ],
  );
}

enum _AllocBy { kantong, kind }

class _AllocationCard extends StatefulWidget {
  const _AllocationCard({required this.summary, required this.kantong});

  final DashboardSummary summary;
  final List<Kantong> kantong;

  @override
  State<_AllocationCard> createState() => _AllocationCardState();
}

class _Slice {
  const _Slice(this.label, this.amount, this.color);
  final String label;
  final Decimal amount;
  final Color color;
}

class _AllocationCardState extends State<_AllocationCard> {
  _AllocBy _by = _AllocBy.kantong;

  List<_Slice> _slices(AppColors c) {
    if (_by == _AllocBy.kantong) {
      return [
        for (final k in widget.kantong)
          if (k.figures.value > Decimal.zero)
            _Slice('${k.emoji} ${k.name}', k.figures.value, k.color.color),
      ]..sort((a, b) => b.amount.compareTo(a.amount));
    }
    final palette = KantongColor.values;
    return [
      for (final (i, e) in widget.summary.categories.entries.indexed)
        if (e.value > Decimal.zero)
          _Slice(
            HoldingCategory.fromDb(e.key).label,
            e.value,
            palette[i % palette.length].color,
          ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final slices = _slices(c);
    final total = slices.fold(Decimal.zero, (a, s) => a + s.amount);
    String share(Decimal v) => total == Decimal.zero
        ? '0%'
        : formatPercent(
            (v * Decimal.fromInt(100) / total).toDecimal(
              scaleOnInfinitePrecision: 4,
            ),
            decimals: 0,
            signed: false,
          );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: [
              Text('Alokasi', style: context.text.titleMedium),
              SegmentedButton<_AllocBy>(
                segments: const [
                  ButtonSegment(
                    value: _AllocBy.kantong,
                    label: Text('Kantong'),
                  ),
                  ButtonSegment(
                    value: _AllocBy.kind,
                    label: Text('Jenis aset'),
                  ),
                ],
                selected: {_by},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _by = s.first),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          if (slices.isEmpty)
            Text('Belum ada nilai untuk dibagi.', style: context.text.bodySmall)
          else
            Row(
              children: [
                SizedBox.square(
                  dimension: AppLayout.donut,
                  child: Semantics(
                    label: 'Diagram alokasi',
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: AppLayout.donut * 0.32,
                        sections: [
                          for (final s in slices)
                            PieChartSectionData(
                              value: s.amount.toDouble(),
                              color: s.color,
                              radius: AppLayout.donut * 0.16,
                              showTitle: false,
                            ),
                        ],
                      ),
                      duration: AppMotion.short,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s16),
                Expanded(
                  child: Column(
                    children: [
                      for (final s in slices)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.s4,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: AppSpacing.s8,
                                height: AppSpacing.s8,
                                decoration: BoxDecoration(
                                  color: s.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s8),
                              Expanded(
                                child: Text(
                                  s.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.text.bodySmall?.copyWith(
                                    color: c.fg,
                                  ),
                                ),
                              ),
                              Text(share(s.amount), style: context.nums.numSm),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            'Total aset ${formatCardAmount(total)}. Utang tidak masuk '
            'diagram.',
            style: context.text.bodySmall,
          ),
        ],
      ),
    );
  }
}
