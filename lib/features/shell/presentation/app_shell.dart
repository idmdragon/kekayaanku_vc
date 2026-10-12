import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../profile/application/profile_controller.dart';
import 'add_sheet.dart';

class _Dest {
  const _Dest(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Branch order matches the router's StatefulShellRoute.
const _dests = [
  _Dest('Beranda', AppIcons.home),
  _Dest('Kantong', AppIcons.wallet),
  _Dest('Statistik', AppIcons.stats),
  _Dest('Riwayat', AppIcons.history),
];

void openAddSheet(BuildContext context) => showAppSheet<void>(
  context,
  title: 'Tambah',
  builder: (_) => const AddSheet(),
);

/// Bottom navigation with a centre Tambah button on phones and tablets,
/// a fixed sidebar on wide screens (docs/design-system.md 7, DS-1).
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  void _go(int i) =>
      shell.goBranch(i, initialLocation: i == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= AppBreakpoints.expanded;
    final body = CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN): () {
          // Ignore the shortcut while typing.
          final focused = FocusManager.instance.primaryFocus?.context?.widget;
          if (focused is EditableText) return;
          openAddSheet(context);
        },
      },
      child: Focus(autofocus: true, child: shell),
    );

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            _Sidebar(current: shell.currentIndex, onSelect: _go),
            Expanded(child: body),
          ],
        ),
      );
    }
    return Scaffold(
      body: body,
      bottomNavigationBar: _BottomBar(
        current: shell.currentIndex,
        onSelect: _go,
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.current, required this.onSelect});

  final int current;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget tab(int i) => Expanded(
      child: _TabButton(
        dest: _dests[i],
        selected: i == current,
        onTap: () => onSelect(i),
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
          child: Row(
            children: [
              tab(0),
              tab(1),
              Expanded(
                // heightFactor keeps the bar as tall as its content.
                child: Center(
                  heightFactor: 1,
                  child: Semantics(
                    button: true,
                    label: 'Tambah',
                    child: Tooltip(
                      message: 'Tambah (N)',
                      child: Material(
                        color: c.accent,
                        shape: const CircleBorder(),
                        elevation: AppElevation.floating,
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => openAddSheet(context),
                          child: SizedBox.square(
                            dimension: AppLayout.addButton,
                            child: Icon(
                              AppIcons.add,
                              color: c.onAccent,
                              size: AppLayout.iconSize,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              tab(2),
              tab(3),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.dest,
    required this.selected,
    required this.onTap,
  });

  final _Dest dest;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      selected: selected,
      button: true,
      label: dest.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kMinTapTarget),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: AppMotion.short,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s16,
                  vertical: AppSpacing.s4,
                ),
                decoration: ShapeDecoration(
                  color: selected ? c.accentSoft : c.surface,
                  shape: const StadiumBorder(),
                ),
                child: Icon(
                  dest.icon,
                  size: AppLayout.iconSize,
                  color: selected ? c.accent : c.muted,
                ),
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(
                dest.label,
                style: context.text.labelMedium
                    ?.copyWith(color: selected ? c.fg : c.muted)
                    .weight(selected ? FontWeight.w700 : FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({required this.current, required this.onSelect});

  final int current;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final name = ref.watch(profileControllerProvider).value?.displayName ?? '';
    return Container(
      width: AppLayout.sidebarWidth,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(right: BorderSide(color: c.line)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Kekayaanku', style: context.text.titleLarge),
              const SizedBox(height: AppSpacing.s24),
              FilledButton.icon(
                onPressed: () => openAddSheet(context),
                icon: const Icon(AppIcons.add),
                label: const Text('Tambah'),
              ),
              const SizedBox(height: AppSpacing.s16),
              for (final (i, d) in _dests.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s4),
                  child: Semantics(
                    selected: i == current,
                    child: Material(
                      color: i == current ? c.accentSoft : c.surface,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => onSelect(i),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: kMinTapTarget,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.s12,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  d.icon,
                                  size: AppLayout.iconSize,
                                  color: i == current ? c.accent : c.muted,
                                ),
                                const SizedBox(width: AppSpacing.s12),
                                Text(
                                  d.label,
                                  style: context.text.bodyMedium?.weight(
                                    i == current
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              const Spacer(),
              Divider(color: c.line),
              const SizedBox(height: AppSpacing.s8),
              Row(
                children: [
                  const UserAvatar.button(),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodyMedium,
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
