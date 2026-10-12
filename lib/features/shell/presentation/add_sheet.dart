import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/list_group.dart';
import '../../holdings/presentation/cash_sheets.dart';

/// The Tambah sheet: Transaksi and Lainnya (docs/design-system.md 7.1).
/// Beli and jual arrive with the stock and crypto slices.
class AddSheet extends StatelessWidget {
  const AddSheet({super.key});

  @override
  Widget build(BuildContext context) {
    void go(String path) {
      Navigator.of(context).pop();
      context.push(path);
    }

    void flow(bool inflow) {
      // Open from the shell's context: this sheet's context goes away.
      final nav = Navigator.of(context);
      final host = nav.context;
      nav.pop();
      showFlowSheet(host, inflow: inflow);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Transaksi'),
        const SizedBox(height: AppSpacing.s8),
        _ActionGrid(
          actions: [
            const _Action('Beli', AppIcons.buy),
            const _Action('Jual', AppIcons.sell),
            _Action('Setor', AppIcons.deposit, onTap: () => flow(true)),
            _Action('Tarik', AppIcons.withdraw, onTap: () => flow(false)),
          ],
        ),
        const SizedBox(height: AppSpacing.s8),
        Text(
          'Beli dan jual aktif bersama pencatatan saham dan kripto.',
          style: context.text.bodySmall,
        ),
        const SizedBox(height: AppSpacing.s16),
        const SectionLabel('Lainnya'),
        const SizedBox(height: AppSpacing.s8),
        _ActionGrid(
          actions: [
            _Action('Aset baru', AppIcons.add, onTap: () => go('/aset/baru')),
            _Action(
              'Kantong baru',
              AppIcons.wallet,
              onTap: () => go('/kantong/baru'),
            ),
          ],
        ),
      ],
    );
  }
}

class _Action {
  const _Action(this.label, this.icon, {this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({required this.actions});

  final List<_Action> actions;

  static const _columns = 4;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return LayoutBuilder(
      builder: (context, box) {
        final cell = (box.maxWidth - AppSpacing.s8 * (_columns - 1)) / _columns;
        return Wrap(
          spacing: AppSpacing.s8,
          runSpacing: AppSpacing.s8,
          children: [
            for (final a in actions)
              SizedBox(
                width: cell,
                child: Semantics(
                  button: true,
                  enabled: a.onTap != null,
                  label: a.label,
                  excludeSemantics: true,
                  child: Material(
                    color: c.surface2,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: a.onTap,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.s12,
                          horizontal: AppSpacing.s4,
                        ),
                        child: Column(
                          children: [
                            Icon(
                              a.icon,
                              size: AppLayout.iconSize,
                              color: a.onTap == null ? c.muted : c.accent,
                            ),
                            const SizedBox(height: AppSpacing.s4),
                            Text(
                              a.label,
                              textAlign: TextAlign.center,
                              style: context.text.labelMedium?.copyWith(
                                color: a.onTap == null ? c.muted : c.fg,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
