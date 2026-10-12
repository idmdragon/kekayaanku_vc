import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/user_message.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../../shared/widgets/list_group.dart';
import '../../../shared/widgets/page_frame.dart';
import '../../../shared/widgets/states.dart';
import '../../../shared/widgets/top_bar.dart';
import '../../profile/application/profile_controller.dart';
import '../../profile/domain/profile.dart';
import '../application/kantong_controller.dart';
import '../domain/kantong.dart';
import 'kantong_widgets.dart';

class KantongListScreen extends ConsumerWidget {
  const KantongListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kantong = ref.watch(kantongListProvider);
    final view =
        ref.watch(profileControllerProvider).value?.kantongView ??
        KantongView.list;

    return Scaffold(
      body: PageFrame(
        // Full-width cards read best narrow; the grid uses the wide layout.
        maxWidth: view == KantongView.grid
            ? AppLayout.wideMaxWidth
            : AppLayout.contentMaxWidth,
        header: TopBar(
          title: 'Kantong',
          showAvatar: true,
          actions: [_ViewToggle(view: view)],
        ),
        children: kantong.when(
          skipLoadingOnReload: true,
          loading: () => const [_LoadingCards()],
          error: (e, _) => [
            ErrorPanel(
              what: 'Daftar kantong gagal dimuat.',
              error: e,
              onRetry: () => ref.invalidate(kantongControllerProvider),
            ),
          ],
          data: (all) {
            final active = all.where((k) => !k.archived).toList();
            final archived = all.where((k) => k.archived).toList();
            return [
              if (active.isEmpty)
                EmptyState(
                  icon: AppIcons.wallet,
                  title: 'Belum ada kantong',
                  message:
                      'Kantong mengelompokkan aset sesuka Anda, mis. "Saham '
                      'Trading" atau "Dana Darurat". Total semua kantong '
                      'adalah kekayaan bersih Anda.',
                  actionLabel: 'Buat kantong pertama',
                  onAction: () => context.push('/kantong/baru'),
                )
              else ...[
                if (view == KantongView.grid)
                  _Grid(kantong: active)
                else
                  for (final k in active)
                    KantongCard(
                      kantong: k,
                      onTap: () => context.push('/kantong/${k.id}'),
                    ),
                if (view == KantongView.list)
                  NewKantongTile(onTap: () => context.push('/kantong/baru')),
                if (active.length > 1)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _openReorder(context, active),
                      icon: const Icon(AppIcons.move),
                      label: const Text('Atur urutan'),
                    ),
                  ),
              ],
              if (archived.isNotEmpty) _ArchivedSection(kantong: archived),
            ];
          },
        ),
      ),
    );
  }

  void _openReorder(BuildContext context, List<Kantong> active) {
    showAppSheet<void>(
      context,
      title: 'Atur urutan kantong',
      builder: (_) => _ReorderList(initial: active),
    );
  }
}

class _ViewToggle extends ConsumerWidget {
  const _ViewToggle({required this.view});

  final KantongView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    Widget button(KantongView v, IconData icon, String label) {
      final on = v == view;
      return Semantics(
        selected: on,
        child: Tooltip(
          message: label,
          child: Material(
            color: on ? c.surface2 : c.surface,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: on
                  ? null
                  : () => ref
                        .read(profileControllerProvider.notifier)
                        .setKantongView(v)
                        .catchError((Object e) {
                          if (context.mounted) _snack(context, e);
                        }),
              child: SizedBox(
                width: kMinTapTarget,
                height: AppLayout.avatar,
                child: Icon(
                  icon,
                  size: AppLayout.iconSizeSmall,
                  color: on ? c.fg : c.muted,
                  semanticLabel: label,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: ShapeDecoration(
        color: c.surface,
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(KantongView.list, AppIcons.viewList, 'Tampilan daftar'),
          button(KantongView.grid, AppIcons.viewGrid, 'Tampilan grid'),
        ],
      ),
    );
  }
}

void _snack(BuildContext context, Object e) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(userMessage(e))));

class _Grid extends StatelessWidget {
  const _Grid({required this.kantong});

  final List<Kantong> kantong;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final width = MediaQuery.sizeOf(context).width;
        final columns = width >= AppBreakpoints.expanded
            ? 4
            : width >= AppBreakpoints.medium
            ? 3
            : 2;
        final cell = (box.maxWidth - AppSpacing.s12 * (columns - 1)) / columns;
        return Wrap(
          spacing: AppSpacing.s12,
          runSpacing: AppSpacing.s12,
          children: [
            for (final k in kantong)
              SizedBox(
                width: cell,
                child: KantongGridCard(
                  kantong: k,
                  onTap: () => context.push('/kantong/${k.id}'),
                ),
              ),
            SizedBox(
              width: cell,
              child: NewKantongTile(
                label: '+\nKantong baru',
                onTap: () => context.push('/kantong/baru'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LoadingCards extends StatelessWidget {
  const _LoadingCards();

  @override
  Widget build(BuildContext context) => const LoadingRegion(
    child: Column(
      children: [
        Skeleton(height: AppLayout.skeletonCard, radius: AppRadius.xl),
        SizedBox(height: AppSpacing.s12),
        Skeleton(height: AppLayout.skeletonCard, radius: AppRadius.xl),
      ],
    ),
  );
}

class _ArchivedSection extends StatelessWidget {
  const _ArchivedSection({required this.kantong});

  final List<Kantong> kantong;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel('Diarsipkan · ${kantong.length}'),
        const SizedBox(height: AppSpacing.s8),
        ListGroup(
          children: [
            for (final k in kantong)
              InkWell(
                onTap: () => context.push('/kantong/${k.id}'),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.s12),
                  child: Row(
                    children: [
                      KantongEmojiBox(
                        emoji: k.emoji,
                        color: k.color,
                        size: AppLayout.emojiBoxSmall,
                      ),
                      const SizedBox(width: AppSpacing.s12),
                      Expanded(
                        child: Text(k.name, style: context.text.bodyMedium),
                      ),
                      Icon(
                        AppIcons.forward,
                        size: AppLayout.iconSizeSmall,
                        color: context.colors.muted,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ReorderList extends ConsumerStatefulWidget {
  const _ReorderList({required this.initial});

  final List<Kantong> initial;

  @override
  ConsumerState<_ReorderList> createState() => _ReorderListState();
}

class _ReorderListState extends ConsumerState<_ReorderList> {
  late final List<Kantong> _items = [...widget.initial];
  bool _busy = false;

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref.read(kantongControllerProvider.notifier).reorder([
        for (final k in _items) k.id,
      ]);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _snack(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Seret untuk mengubah urutan di tab Kantong.',
          style: context.text.bodySmall,
        ),
        const SizedBox(height: AppSpacing.s12),
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorderItem: (from, to) => setState(() {
            _items.insert(to, _items.removeAt(from));
          }),
          children: [
            for (final (i, k) in _items.indexed)
              ListTile(
                key: ValueKey(k.id),
                contentPadding: EdgeInsets.zero,
                leading: KantongEmojiBox(
                  emoji: k.emoji,
                  color: k.color,
                  size: AppLayout.emojiBoxSmall,
                ),
                title: Text(k.name, style: context.text.bodyMedium),
                trailing: ReorderableDragStartListener(
                  index: i,
                  child: Icon(
                    AppIcons.grip,
                    color: c.muted,
                    semanticLabel: 'Seret ${k.name}',
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.s16),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: const Text('Simpan urutan'),
        ),
      ],
    );
  }
}
