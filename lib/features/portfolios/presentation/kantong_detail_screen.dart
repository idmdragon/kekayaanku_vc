import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/user_message.dart';
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
import '../application/kantong_controller.dart';
import '../domain/kantong.dart';
import 'kantong_widgets.dart';

enum _Tab { aset, riwayat, transaksi, info }

class KantongDetailScreen extends ConsumerStatefulWidget {
  const KantongDetailScreen({super.key, required this.kantongId});

  final String kantongId;

  @override
  ConsumerState<KantongDetailScreen> createState() =>
      _KantongDetailScreenState();
}

class _KantongDetailScreenState extends ConsumerState<KantongDetailScreen> {
  _Tab _tab = _Tab.aset;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(kantongByIdProvider(widget.kantongId));
    return Scaffold(
      body: async.when(
        loading: () => const PageFrame(
          header: TopBar(title: 'Kantong', showBack: true),
          children: [
            LoadingRegion(
              child: Skeleton(
                height: AppLayout.skeletonHero,
                radius: AppRadius.xl,
              ),
            ),
          ],
        ),
        error: (e, _) => PageFrame(
          header: const TopBar(title: 'Kantong', showBack: true),
          children: [
            ErrorPanel(
              what: 'Kantong gagal dimuat.',
              error: e,
              onRetry: () => ref.invalidate(kantongControllerProvider),
            ),
          ],
        ),
        data: (k) {
          if (k == null) {
            return PageFrame(
              header: const TopBar(title: 'Kantong', showBack: true),
              children: [
                EmptyState(
                  title: 'Kantong tidak ditemukan',
                  message: 'Mungkin sudah dihapus.',
                  actionLabel: 'Ke daftar kantong',
                  onAction: () => context.go('/kantong'),
                ),
              ],
            );
          }
          return PageFrame(
            header: TopBar(
              title: '${k.emoji} ${k.name}',
              showBack: true,
              actions: [
                CircleIconButton(
                  icon: AppIcons.edit,
                  label: 'Ubah kantong',
                  onPressed: () => context.push('/kantong/${k.id}/ubah'),
                ),
              ],
            ),
            children: [
              if (k.archived) const _ArchivedNote(),
              _Hero(kantong: k),
              _Tabs(
                selected: _tab,
                assetCount: k.figures.assetCount,
                onSelect: (t) => setState(() => _tab = t),
              ),
              ...switch (_tab) {
                _Tab.aset => _assetTab(k),
                _Tab.riwayat => const [
                  EmptyState(
                    title: 'Belum ada riwayat P/L',
                    message:
                        'Riwayat mulai terisi dari snapshot pertama setelah '
                        'kantong berisi aset.',
                  ),
                ],
                _Tab.transaksi => const [
                  EmptyState(
                    title: 'Belum ada transaksi',
                    message:
                        'Beli, jual, setor, dan tarik di kantong ini akan '
                        'tercatat di sini.',
                  ),
                ],
                _Tab.info => [_InfoTab(kantong: k)],
              },
            ],
          );
        },
      ),
    );
  }

  List<Widget> _assetTab(Kantong k) => [
    EmptyState(
      emoji: k.emoji,
      title: 'Kantong masih kosong',
      message:
          'Pencatatan aset (saham, kripto, emas, reksadana, deposito, rupiah, '
          'valas) hadir di pembaruan berikutnya. Kantong ini sudah siap '
          'menampungnya.',
    ),
  ];
}

class _ArchivedNote extends StatelessWidget {
  const _ArchivedNote();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Icon(AppIcons.archive, color: c.warning, size: AppLayout.iconSize),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Text(
              'Kantong ini diarsipkan dan tidak tampil di daftar utama.',
              style: context.text.bodySmall?.copyWith(color: c.fg),
            ),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.kantong});

  final Kantong kantong;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final k = kantong;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        gradient: c.kantongGradient(k.color, hero: true),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: c.kantongTint(k.color, amount: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nilai kantong',
            style: context.text.bodySmall?.copyWith(
              color: c.kantongMuted(k.color),
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            formatRupiah(k.figures.value),
            style: context.text.displayLarge?.copyWith(
              fontFeatures: context.nums.num.fontFeatures,
            ),
          ),
          Text(
            k.figures.assetCount == 0
                ? 'Belum ada aset di kantong ini'
                : '${k.figures.assetCount} aset',
            style: context.text.bodySmall?.copyWith(
              color: c.kantongMuted(k.color),
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          KantongFiguresRow(kantong: k),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.selected,
    required this.assetCount,
    required this.onSelect,
  });

  final _Tab selected;
  final int assetCount;
  final ValueChanged<_Tab> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final labels = {
      _Tab.aset: 'Aset $assetCount',
      _Tab.riwayat: 'Riwayat P/L',
      _Tab.transaksi: 'Transaksi',
      _Tab.info: 'Info',
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final t in _Tab.values)
              Semantics(
                selected: t == selected,
                button: true,
                child: InkWell(
                  onTap: () => onSelect(t),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: kMinTapTarget),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s8,
                    ),
                    alignment: Alignment.center,
                    // Only the selected tab draws over the shared hairline.
                    decoration: t == selected
                        ? BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: c.accent,
                                width: AppSpacing.s4 / 2,
                              ),
                            ),
                          )
                        : null,
                    child: Text(
                      labels[t]!,
                      style: context.text.bodyMedium
                          ?.copyWith(color: t == selected ? c.fg : c.muted)
                          .weight(FontWeight.w500),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoTab extends ConsumerWidget {
  const _InfoTab({required this.kantong});

  final Kantong kantong;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = kantong;
    final ctrl = ref.read(kantongControllerProvider.notifier);

    Future<void> run(Future<void> Function() action) async {
      try {
        await action();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(userMessage(e))));
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListGroup(
          children: [
            _InfoRow(label: 'Warna', value: k.color.label),
            _InfoRow(
              label: 'Kas kantong',
              value: k.cashEnabled ? 'Aktif, rupiah' : 'Tidak dipakai',
            ),
            _InfoRow(label: 'Dibuat', value: formatDateShort(k.createdAt)),
            if (k.note != null) _InfoRow(label: 'Catatan', value: k.note!),
          ],
        ),
        const SizedBox(height: AppSpacing.s12),
        ListGroup(
          children: [
            ListRow(
              icon: AppIcons.edit,
              title: 'Ubah nama, emoji, dan warna',
              onTap: () => context.push('/kantong/${k.id}/ubah'),
            ),
            ListRow(
              icon: k.archived ? AppIcons.unarchive : AppIcons.archive,
              title: k.archived ? 'Keluarkan dari arsip' : 'Arsipkan kantong',
              subtitle: k.archived
                  ? null
                  : 'Disembunyikan dari daftar utama, data tetap tersimpan',
              onTap: () =>
                  run(() => ctrl.setArchived(k.id, archived: !k.archived)),
            ),
            ListRow(
              icon: AppIcons.delete,
              title: 'Hapus kantong',
              subtitle: 'Hanya bisa jika kantong kosong',
              destructive: true,
              onTap: () async {
                final ok = await _confirmDelete(context, k);
                if (ok != true) return;
                await run(() async {
                  await ctrl.delete(k.id);
                  if (context.mounted) context.go('/kantong');
                });
              },
            ),
          ],
        ),
      ],
    );
  }

  Future<bool?> _confirmDelete(BuildContext context, Kantong k) {
    final c = context.colors;
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('Hapus ${k.name}?', style: context.text.titleLarge),
        content: Text(
          'Kantong yang dihapus tidak bisa dikembalikan.',
          style: context.text.bodyMedium,
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
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.s12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: context.text.bodySmall)),
        const SizedBox(width: AppSpacing.s12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: context.text.bodyMedium,
          ),
        ),
      ],
    ),
  );
}
