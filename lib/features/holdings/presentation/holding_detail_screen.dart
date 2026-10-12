import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/user_message.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/list_group.dart';
import '../../../shared/widgets/page_frame.dart';
import '../../../shared/widgets/states.dart';
import '../../../shared/widgets/top_bar.dart';
import '../../portfolios/application/kantong_controller.dart';
import '../application/finance_providers.dart';
import '../domain/holding.dart';
import 'add_asset_screens.dart';
import 'cash_sheets.dart';
import 'cash_widgets.dart';

/// Detail of a rupiah holding or a kantong's cash: balance, actions and
/// its transactions.
class HoldingDetailScreen extends ConsumerWidget {
  const HoldingDetailScreen({super.key, required this.holdingId});

  final String holdingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(holdingByIdProvider(holdingId));
    return Scaffold(
      body: async.when(
        skipLoadingOnReload: true,
        loading: () => const PageFrame(
          header: TopBar(title: 'Aset', showBack: true),
          children: [
            LoadingRegion(child: Skeleton(height: AppLayout.skeletonHero)),
          ],
        ),
        error: (e, _) => PageFrame(
          header: const TopBar(title: 'Aset', showBack: true),
          children: [
            ErrorPanel(
              what: 'Aset gagal dimuat.',
              error: e,
              onRetry: () => ref.invalidate(holdingsProvider),
            ),
          ],
        ),
        data: (h) => h == null
            ? PageFrame(
                header: const TopBar(title: 'Aset', showBack: true),
                children: [
                  EmptyState(
                    title: 'Aset tidak ditemukan',
                    message: 'Mungkin sudah dihapus.',
                    actionLabel: 'Ke daftar kantong',
                    onAction: () => context.go('/kantong'),
                  ),
                ],
              )
            : _Detail(holding: h),
      ),
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.holding});

  final Holding holding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final h = holding;
    final kantong = ref.watch(kantongByIdProvider(h.portfolioId)).value;
    final txs = ref.watch(holdingTransactionsProvider(h.id));
    final title = h.isCash && kantong != null ? 'Kas ${kantong.name}' : h.name;

    return PageFrame(
      header: TopBar(
        title: title,
        showBack: true,
        actions: [
          if (!h.isCash)
            CircleIconButton(
              icon: AppIcons.edit,
              label: 'Ubah nama',
              onPressed: () => _rename(context, ref),
            ),
        ],
      ),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.s16),
          decoration: BoxDecoration(
            gradient: kantong == null
                ? null
                : c.kantongGradient(kantong.color, hero: true),
            color: kantong == null ? c.surface : null,
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                [
                  h.category.label,
                  if (h.form != null) h.form!.label,
                  if (kantong != null) '${kantong.emoji} ${kantong.name}',
                ].join(' · '),
                style: context.text.bodySmall?.copyWith(
                  color: kantong == null
                      ? c.muted
                      : c.kantongMuted(kantong.color),
                ),
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(
                formatRupiah(h.qty),
                style: context.text.displayLarge?.copyWith(
                  fontFeatures: context.nums.num.fontFeatures,
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: AppIcons.setBalance,
                label: 'Set saldo',
                onTap: () => showSetBalanceSheet(context, h),
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: _ActionButton(
                icon: AppIcons.deposit,
                label: 'Setor',
                onTap: () =>
                    showFlowSheet(context, inflow: true, holdingId: h.id),
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: _ActionButton(
                icon: AppIcons.withdraw,
                label: 'Tarik',
                onTap: () =>
                    showFlowSheet(context, inflow: false, holdingId: h.id),
              ),
            ),
          ],
        ),
        const SectionLabel('Transaksi'),
        ...txs.when(
          skipLoadingOnReload: true,
          loading: () => const [
            LoadingRegion(child: Skeleton(height: AppLayout.skeletonCard)),
          ],
          error: (e, _) => [
            ErrorPanel(
              what: 'Transaksi gagal dimuat.',
              error: e,
              onRetry: () => ref.invalidate(holdingTransactionsProvider(h.id)),
            ),
          ],
          data: (list) => [
            if (list.isEmpty)
              const EmptyState(
                title: 'Belum ada transaksi',
                message: 'Setor, tarik, dan set saldo tercatat di sini.',
              )
            else
              ListGroup(
                children: [
                  for (final tx in list)
                    TransactionTile(
                      tx: tx,
                      onTap: () => showTransactionSheet(
                        context,
                        tx,
                        firstDate: h.startedOn,
                      ),
                    ),
                ],
              ),
          ],
        ),
        if (!h.isCash)
          ListGroup(
            children: [
              ListRow(
                icon: AppIcons.delete,
                title: 'Hapus aset',
                subtitle: 'Beserta semua transaksinya',
                destructive: true,
                onTap: () => _delete(context, ref),
              ),
            ],
          ),
      ],
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController(text: holding.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ubah nama'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: kHoldingNameMax,
          decoration: const InputDecoration(counterText: ''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || name.isEmpty || name == holding.name) return;
    try {
      await ref.read(financeActionsProvider).renameHolding(holding.id, name);
    } catch (e) {
      if (context.mounted) _toast(context, userMessage(e));
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final c = context.colors;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus ${holding.name}?'),
        content: const Text(
          'Aset dan semua transaksinya dihapus. Snapshot yang sudah tercatat '
          'tidak berubah; saldo yang hilang dicatat sebagai penarikan di '
          'snapshot berikutnya.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: c.negative),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(financeActionsProvider).deleteHolding(holding.id);
      if (context.mounted) context.pop();
    } catch (e) {
      if (context.mounted) _toast(context, userMessage(e));
    }
  }
}

void _toast(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
            child: Column(
              children: [
                Icon(icon, color: c.accent, size: AppLayout.iconSize),
                const SizedBox(height: AppSpacing.s4),
                Text(label, style: context.text.labelMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
