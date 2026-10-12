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
import '../../holdings/application/finance_providers.dart';
import '../../holdings/presentation/opening_note.dart';
import '../application/kantong_controller.dart';
import '../domain/kantong.dart';
import 'kantong_widgets.dart';

/// Create a kantong, or edit one when [kantongId] is given
/// (docs/design-system.md 7.1 "Buat kantong").
class KantongEditorScreen extends ConsumerWidget {
  const KantongEditorScreen({super.key, this.kantongId});

  final String? kantongId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = kantongId;
    if (id == null) return const _Editor(existing: null);
    return ref
        .watch(kantongByIdProvider(id))
        .when(
          loading: () => const Scaffold(
            body: PageFrame(
              header: TopBar(title: 'Ubah kantong', showBack: true),
              children: [Skeleton(height: AppLayout.skeletonHero)],
            ),
          ),
          error: (e, _) => Scaffold(
            body: PageFrame(
              header: const TopBar(title: 'Ubah kantong', showBack: true),
              children: [
                ErrorPanel(
                  what: 'Kantong gagal dimuat.',
                  error: e,
                  onRetry: () => ref.invalidate(kantongControllerProvider),
                ),
              ],
            ),
          ),
          data: (k) => k == null
              ? const _MissingKantong()
              : _Editor(key: ValueKey(k.id), existing: k),
        );
  }
}

class _MissingKantong extends StatelessWidget {
  const _MissingKantong();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: PageFrame(
      header: const TopBar(title: 'Kantong', showBack: true),
      children: [
        EmptyState(
          title: 'Kantong tidak ditemukan',
          message: 'Mungkin sudah dihapus. Kembali ke daftar kantong.',
          actionLabel: 'Ke daftar kantong',
          onAction: () => context.go('/kantong'),
        ),
      ],
    ),
  );
}

class _Editor extends ConsumerStatefulWidget {
  const _Editor({super.key, required this.existing});

  final Kantong? existing;

  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor> {
  final _form = GlobalKey<FormState>();
  late KantongDraft _draft = widget.existing?.toDraft() ?? const KantongDraft();
  late final _name = TextEditingController(text: _draft.name);
  late final _note = TextEditingController(text: _draft.note);
  final _customEmoji = TextEditingController();
  final _openingCash = TextEditingController();
  bool _busy = false;
  String? _error;

  bool get _editing => widget.existing != null;

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    _customEmoji.dispose();
    _openingCash.dispose();
    super.dispose();
  }

  void _set(KantongDraft d) => setState(() => _draft = d);

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final draft = _draft.copyWith(name: _name.text, note: _note.text);
    final ctrl = ref.read(kantongControllerProvider.notifier);
    try {
      if (_editing) {
        await ctrl.save(widget.existing!.id, draft);
        if (mounted) context.pop();
      } else {
        final k = await ctrl.create(draft);
        final opening = draft.cashEnabled
            ? parseRupiahInput(_openingCash.text)
            : null;
        if (opening != null && opening > Decimal.zero) {
          try {
            await ref
                .read(financeActionsProvider)
                .openKantongCash(k.id, opening);
          } catch (e) {
            // The kantong exists; say what is missing instead of failing.
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Kantong dibuat, tetapi saldo awal kas belum tersimpan. '
                    '${userMessage(e)}',
                  ),
                ),
              );
            }
          }
        }
        if (mounted) context.pushReplacement('/kantong/${k.id}');
      }
    } catch (e) {
      if (mounted) setState(() => _error = userMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = Kantong(
      id: 'preview',
      name: _name.text.trim().isEmpty ? 'Nama kantong' : _name.text.trim(),
      emoji: _draft.emoji,
      color: _draft.color,
      cashEnabled: _draft.cashEnabled,
      note: null,
      sortOrder: 0,
      archivedAt: null,
      createdAt: DateTime.now(),
      figures: widget.existing?.figures,
    );

    return Scaffold(
      body: Form(
        key: _form,
        child: PageFrame(
          header: TopBar(
            title: _editing ? 'Ubah kantong' : 'Kantong baru',
            showBack: true,
          ),
          bottom: BusyButton(
            label: _editing ? 'Simpan perubahan' : 'Buat kantong',
            busy: _busy,
            onPressed: _save,
          ),
          children: [
            Semantics(
              label: 'Pratinjau',
              child: KantongCard(kantong: preview),
            ),
            if (_error != null) FormMessage.error(_error!),
            LabeledField(
              label: 'Nama kantong',
              child: TextFormField(
                controller: _name,
                maxLength: kKantongNameMax,
                validator: validateKantongName,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'mis. Liburan Jepang',
                  counterText: '',
                ),
              ),
            ),
            _EmojiPicker(
              selected: _draft.emoji,
              custom: _customEmoji,
              onPick: (e) => _set(_draft.copyWith(emoji: e)),
            ),
            _ColorPicker(
              selected: _draft.color,
              onPick: (k) => _set(_draft.copyWith(color: k)),
            ),
            _CashSwitch(
              value: _draft.cashEnabled,
              onChanged: (v) => _set(_draft.copyWith(cashEnabled: v)),
            ),
            if (_draft.cashEnabled && !_editing)
              LabeledField(
                label: 'Saldo awal kas (opsional)',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RupiahField(
                      controller: _openingCash,
                      required: false,
                      allowZero: true,
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    const OpeningNote(),
                  ],
                ),
              ),
            LabeledField(
              label: 'Catatan (opsional)',
              child: TextFormField(
                controller: _note,
                maxLength: kKantongNoteMax,
                maxLines: 3,
                minLines: 1,
                decoration: const InputDecoration(
                  hintText: 'mis. target Mei 2027',
                  counterText: '',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmojiPicker extends StatelessWidget {
  const _EmojiPicker({
    required this.selected,
    required this.custom,
    required this.onPick,
  });

  final String selected;
  final TextEditingController custom;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return LabeledField(
      label: 'Emoji',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.s4,
            runSpacing: AppSpacing.s4,
            children: [
              for (final e in kKantongEmoji)
                Semantics(
                  selected: e == selected,
                  button: true,
                  label: 'Emoji $e',
                  child: Material(
                    color: e == selected ? c.accentSoft : c.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      side: BorderSide(
                        color: e == selected ? c.accent : c.surface,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => onPick(e),
                      child: SizedBox.square(
                        dimension: kMinTapTarget,
                        child: Center(
                          child: ExcludeSemantics(
                            child: Text(e, style: context.text.titleLarge),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          TextField(
            controller: custom,
            decoration: const InputDecoration(
              hintText: 'Atau ketik emoji lain',
            ),
            onChanged: (v) {
              final s = v.trim();
              if (s.isEmpty) return;
              // Keep the last grapheme so "🐷🚀" becomes "🚀".
              final last = s.characters.last;
              if (_isEmoji(last)) onPick(last);
            },
          ),
        ],
      ),
    );
  }

  /// Rough check that a grapheme is an emoji, not a letter or digit.
  static bool _isEmoji(String g) =>
      g.runes.any((r) => r >= 0x2190) &&
      !RegExp(r'^[\p{L}\p{N}]+$', unicode: true).hasMatch(g);
}

class _ColorPicker extends StatelessWidget {
  const _ColorPicker({required this.selected, required this.onPick});

  final KantongColor selected;
  final ValueChanged<KantongColor> onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return LabeledField(
      label: 'Warna · ${selected.label}',
      child: Wrap(
        spacing: AppSpacing.s8,
        runSpacing: AppSpacing.s8,
        children: [
          for (final k in KantongColor.values)
            Semantics(
              selected: k == selected,
              button: true,
              label: 'Warna ${k.label}',
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => onPick(k),
                child: SizedBox.square(
                  dimension: kMinTapTarget,
                  child: Center(
                    child: AnimatedContainer(
                      duration: AppMotion.short,
                      width: AppLayout.avatar,
                      height: AppLayout.avatar,
                      decoration: BoxDecoration(
                        color: k.color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: k == selected ? c.fg : c.bg,
                          width: AppSpacing.s4 / 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CashSwitch extends StatelessWidget {
  const _CashSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return LabeledField(
      label: 'Kas kantong',
      child: Material(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: SwitchListTile(
          value: value,
          onChanged: onChanged,
          activeThumbColor: c.onAccent,
          activeTrackColor: c.accent,
          title: Text('Pakai saldo kas rupiah', style: context.text.bodyMedium),
          subtitle: Text(
            'Untuk RDN, saldo exchange, atau dana menunggu. Uang asing '
            'dicatat sebagai aset Valas.',
            style: context.text.bodySmall,
          ),
        ),
      ),
    );
  }
}
