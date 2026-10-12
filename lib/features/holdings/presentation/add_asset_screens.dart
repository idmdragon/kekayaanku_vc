import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/user_message.dart';
import '../../../core/format/amount_input.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/amount_field.dart';
import '../../../shared/widgets/page_frame.dart';
import '../../../shared/widgets/states.dart';
import '../../../shared/widgets/top_bar.dart';
import '../../auth/presentation/auth_widgets.dart';
import '../../portfolios/application/kantong_controller.dart';
import '../../portfolios/domain/kantong.dart';
import '../application/finance_providers.dart';
import '../domain/holding.dart';
import 'cash_widgets.dart';
import 'opening_note.dart';

const int kHoldingNameMax = 60;

/// Kantong picker shown as a tinted chip (docs/design-system.md 7.1).
class KantongPicker extends ConsumerWidget {
  const KantongPicker({
    super.key,
    required this.selectedId,
    required this.onChanged,
  });

  final String? selectedId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final list = (ref.watch(kantongListProvider).value ?? const <Kantong>[])
        .where((k) => !k.archived)
        .toList();
    final current =
        list.where((k) => k.id == selectedId).firstOrNull ?? list.firstOrNull;
    if (current == null) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
        decoration: BoxDecoration(
          color: c.kantongTint(current.color, amount: 0.28),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: current.id,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            dropdownColor: c.surface,
            style: context.text.bodyMedium,
            items: [
              for (final k in list)
                DropdownMenuItem(
                  value: k.id,
                  child: Text('${k.emoji} ${k.name}'),
                ),
            ],
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      ),
    );
  }
}

/// Tambah aset: choose the kind (docs/design-system.md 7.1).
class AddAssetScreen extends ConsumerStatefulWidget {
  const AddAssetScreen({super.key, this.kantongId});

  final String? kantongId;

  @override
  ConsumerState<AddAssetScreen> createState() => _AddAssetScreenState();
}

class _AddAssetScreenState extends ConsumerState<AddAssetScreen> {
  late String? _kantong = widget.kantongId;

  static const _kinds = [
    HoldingCategory.stock,
    HoldingCategory.crypto,
    HoldingCategory.gold,
    HoldingCategory.mutualFund,
    HoldingCategory.deposit,
    HoldingCategory.savingsIdr,
    HoldingCategory.savingsFx,
    HoldingCategory.receivable,
    HoldingCategory.debt,
  ];

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(kantongListProvider);
    final kantongId =
        _kantong ?? list.value?.where((k) => !k.archived).firstOrNull?.id;
    return Scaffold(
      body: PageFrame(
        header: const TopBar(title: 'Tambah aset', showBack: true),
        children: [
          LabeledField(
            label: 'Masuk ke kantong',
            child: KantongPicker(
              selectedId: kantongId,
              onChanged: (v) => setState(() => _kantong = v),
            ),
          ),
          LabeledField(
            label: 'Jenis',
            child: LayoutBuilder(
              builder: (context, box) {
                const cols = 3;
                final cell = (box.maxWidth - AppSpacing.s8 * (cols - 1)) / cols;
                return Wrap(
                  spacing: AppSpacing.s8,
                  runSpacing: AppSpacing.s8,
                  children: [
                    for (final k in _kinds)
                      SizedBox(
                        width: cell,
                        child: _KindTile(
                          kind: k,
                          onTap:
                              k == HoldingCategory.savingsIdr &&
                                  kantongId != null
                              ? () => context.pushReplacement(
                                  '/aset/baru/rupiah?kantong=$kantongId',
                                )
                              : null,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          const NoteText(
            'Jenis menentukan cara hitung nilai dan P/L. Kantong hanya '
            'pengelompokan, jadi satu kantong boleh berisi jenis apa saja. '
            'Jenis lain aktif bertahap di pembaruan berikutnya.',
          ),
        ],
      ),
    );
  }
}

class _KindTile extends StatelessWidget {
  const _KindTile({required this.kind, this.onTap});

  final HoldingCategory kind;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: enabled ? kind.label : '${kind.label}, segera hadir',
      excludeSemantics: true,
      child: Material(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.s16,
              horizontal: AppSpacing.s4,
            ),
            child: Column(
              children: [
                Icon(
                  holdingIcon(kind),
                  color: enabled ? c.accent : c.muted,
                  size: AppLayout.iconSize,
                ),
                const SizedBox(height: AppSpacing.s8),
                Text(
                  kind.label,
                  textAlign: TextAlign.center,
                  style: context.text.labelMedium?.copyWith(
                    color: enabled ? c.fg : c.muted,
                  ),
                ),
                Text(
                  enabled ? 'tabungan / tunai' : 'segera',
                  style: context.text.labelSmall?.copyWith(color: c.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Uang rupiah form (PRD 6.2.6). Valas joins it in slice 4.
class SavingsFormScreen extends ConsumerStatefulWidget {
  const SavingsFormScreen({super.key, this.kantongId});

  final String? kantongId;

  @override
  ConsumerState<SavingsFormScreen> createState() => _SavingsFormScreenState();
}

class _SavingsFormScreenState extends ConsumerState<SavingsFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _amount = TextEditingController();
  late String? _kantong = widget.kantongId;
  SavingsForm _savingsForm = SavingsForm.rekening;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save(String kantongId) async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(financeActionsProvider)
          .createSavings(
            portfolioId: kantongId,
            name: _name.text,
            form: _savingsForm,
            amount: parseRupiahInput(_amount.text) ?? Decimal.zero,
          );
      if (mounted) context.pushReplacement('/kantong/$kantongId');
    } catch (e) {
      if (mounted) setState(() => _error = userMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(kantongListProvider);
    final kantongId =
        _kantong ?? list.value?.where((k) => !k.archived).firstOrNull?.id;
    return Scaffold(
      body: Form(
        key: _form,
        child: PageFrame(
          header: const TopBar(title: 'Uang rupiah', showBack: true),
          bottom: BusyButton(
            label: 'Simpan',
            busy: _busy,
            onPressed: () {
              if (kantongId != null) _save(kantongId);
            },
          ),
          children: [
            if (list.hasError)
              ErrorPanel(
                what: 'Kantong gagal dimuat.',
                error: list.error!,
                onRetry: () => ref.invalidate(kantongControllerProvider),
              ),
            KantongPicker(
              selectedId: kantongId,
              onChanged: (v) => setState(() => _kantong = v),
            ),
            if (_error != null) FormMessage.error(_error!),
            LabeledField(
              label: 'Bentuk',
              child: Align(
                alignment: Alignment.centerLeft,
                child: SegmentedButton<SavingsForm>(
                  segments: [
                    for (final f in SavingsForm.values)
                      ButtonSegment(value: f, label: Text(f.label)),
                  ],
                  selected: {_savingsForm},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) =>
                      setState(() => _savingsForm = s.first),
                ),
              ),
            ),
            LabeledField(
              label: 'Nama',
              child: TextFormField(
                controller: _name,
                maxLength: kHoldingNameMax,
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Beri nama, mis. BCA.' : null,
                decoration: InputDecoration(
                  hintText: _savingsForm == SavingsForm.rekening
                      ? 'mis. Tabungan BCA'
                      : 'mis. Dompet',
                  counterText: '',
                ),
              ),
            ),
            LabeledField(
              label: 'Saldo sekarang',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RupiahField(controller: _amount, allowZero: true),
                  const SizedBox(height: AppSpacing.s4),
                  const OpeningNote(),
                ],
              ),
            ),
            const NoteText(
              'Rupiah tidak perlu konversi; nilainya langsung masuk ke net '
              'worth. Ubah saldo kapan saja lewat "Set saldo", atau catat '
              'setor dan tarik.',
            ),
          ],
        ),
      ),
    );
  }
}
