import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/page_frame.dart';
import '../../../shared/widgets/states.dart';
import '../../../shared/widgets/top_bar.dart';
import '../../portfolios/application/kantong_controller.dart';

/// Beranda. Net worth, chart and allocation arrive with snapshots (slice 2);
/// until then it shows Rp0 and when the first snapshot will be recorded.
class OverviewScreen extends ConsumerWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final kantong = ref.watch(kantongControllerProvider);
    final hasKantong = kantong.value?.any((k) => !k.archived) ?? false;

    return Scaffold(
      body: PageFrame(
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
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.s16),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kekayaan bersih', style: context.text.bodySmall),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  formatRupiah(Decimal.zero),
                  style: context.text.displayLarge?.copyWith(
                    fontFeatures: context.nums.num.fontFeatures,
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  'Snapshot pertama tercatat pukul 18.00 WIB pada hari Anda '
                  'mulai mencatat aset.',
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ),
          if (kantong.isLoading && !kantong.hasValue)
            const LoadingRegion(child: Skeleton(height: AppLayout.skeletonCard))
          else if (kantong.hasError)
            ErrorPanel(
              what: 'Kantong gagal dimuat.',
              error: kantong.error!,
              onRetry: () => ref.invalidate(kantongControllerProvider),
            )
          else if (!hasKantong)
            EmptyState(
              icon: AppIcons.wallet,
              title: 'Mulai dari kantong',
              message:
                  'Buat kantong untuk mengelompokkan aset, mis. "Saham '
                  'Investing" atau "Dana Darurat".',
              actionLabel: 'Buat kantong',
              onAction: () => context.push('/kantong/baru'),
            )
          else
            const EmptyState(
              icon: AppIcons.stats,
              title: 'Grafik muncul setelah aset tercatat',
              message:
                  'Grafik kekayaan, pembanding IHSG atau BTC, dan alokasi '
                  'per kantong tampil di sini setelah snapshot pertama.',
            ),
        ],
      ),
    );
  }
}
