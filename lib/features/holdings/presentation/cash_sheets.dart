import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/user_message.dart';
import '../../../core/format/amount_input.dart';
import '../../../core/format/date.dart';
import '../../../core/format/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/amount_field.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../../shared/widgets/states.dart';
import '../../auth/presentation/auth_widgets.dart';
import '../../portfolios/application/kantong_controller.dart';
import '../../portfolios/domain/kantong.dart';
import '../application/finance_providers.dart';
import '../domain/cash_transaction.dart';
import '../domain/holding.dart';
import 'cash_widgets.dart';

/// Where a setor/tarik goes: a kantong's cash or a rupiah holding.
class _Target {
  const _Target({
    required this.key,
    required this.label,
    required this.balance,
    required this.firstDate,
    this.holdingId,
    this.portfolioId,
  });

  final String key;
  final String label;
  final Decimal balance;
  final DateTime firstDate;
  final String? holdingId;
  final String? portfolioId;
}

List<_Target> _targets(List<Kantong> kantong, List<Holding> holdings) {
  final byId = {for (final k in kantong) k.id: k};
  final out = <_Target>[];
  for (final k in kantong.where((k) => !k.archived && k.cashEnabled)) {
    final cash = holdings
        .where((h) => h.isCash && h.portfolioId == k.id)
        .firstOrNull;
    out.add(
      _Target(
        key: 'cash:${k.id}',
        label: '${k.emoji} ${k.name} · Kas',
        balance: cash?.qty ?? Decimal.zero,
        firstDate: cash?.startedOn ?? DateTime(2000),
        holdingId: cash?.id,
        portfolioId: k.id,
      ),
    );
  }
  for (final h in holdings.where(
    (h) => h.category == HoldingCategory.savingsIdr,
  )) {
    final k = byId[h.portfolioId];
    if (k == null || k.archived) continue;
    out.add(
      _Target(
        key: 'holding:${h.id}',
        label: '${h.name} · ${k.emoji} ${k.name}',
        balance: h.qty,
        firstDate: h.startedOn,
        holdingId: h.id,
      ),
    );
  }
  return out;
}

/// Setor / tarik modal (PRD 7.7). Preselects [holdingId] or the cash of
/// [portfolioId] when given.
Future<void> showFlowSheet(
  BuildContext context, {
  required bool inflow,
  String? holdingId,
  String? portfolioId,
}) => showAppSheet<void>(
  context,
  title: 'Setor atau tarik',
  builder: (_) => _FlowSheet(
    inflow: inflow,
    holdingId: holdingId,
    portfolioId: portfolioId,
  ),
);

class _FlowSheet extends ConsumerStatefulWidget {
  const _FlowSheet({required this.inflow, this.holdingId, this.portfolioId});

  final bool inflow;
  final String? holdingId;
  final String? portfolioId;

  @override
  ConsumerState<_FlowSheet> createState() => _FlowSheetState();
}

class _FlowSheetState extends ConsumerState<_FlowSheet> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  late bool _inflow = widget.inflow;
  DateTime _date = todayWib();
  String? _targetKey;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  _Target? _pick(List<_Target> all) {
    final wanted =
        _targetKey ??
        (widget.holdingId != null
            ? all.where((t) => t.holdingId == widget.holdingId).firstOrNull?.key
            : widget.portfolioId != null
            ? 'cash:${widget.portfolioId}'
            : null);
    return all.where((t) => t.key == wanted).firstOrNull ?? all.firstOrNull;
  }

  Future<void> _save(_Target t) async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(financeActionsProvider)
          .recordFlow(
            holdingId: t.holdingId,
            portfolioId: t.portfolioId,
            inflow: _inflow,
            amount: parseRupiahInput(_amount.text)!,
            date: _date,
            note: _note.text,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = userMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kantong = ref.watch(kantongListProvider);
    final holdings = ref.watch(holdingsProvider);
    if (!kantong.hasValue || !holdings.hasValue) {
      if (kantong.hasError || holdings.hasError) {
        return ErrorPanel(
          what: 'Daftar tujuan gagal dimuat.',
          error: (kantong.error ?? holdings.error)!,
          onRetry: () => ref.invalidate(holdingsProvider),
        );
      }
      return const LoadingRegion(
        child: Skeleton(height: AppLayout.skeletonCard),
      );
    }
    final targets = _targets(kantong.value!, holdings.value!);
    final target = _pick(targets);
    if (target == null) {
      return const EmptyState(
        title: 'Belum ada tempat untuk menyetor',
        message:
            'Nyalakan kas di salah satu kantong atau tambahkan uang rupiah '
            'sebagai aset dulu.',
      );
    }
    final amount = parseRupiahInput(_amount.text);
    final fixed = widget.holdingId != null;

    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Setor')),
              ButtonSegment(value: false, label: Text('Tarik')),
            ],
            selected: {_inflow},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _inflow = s.first),
          ),
          const SizedBox(height: AppSpacing.s16),
          if (_error != null) FormMessage.error(_error!),
          LabeledField(
            label: _inflow ? 'Ke' : 'Dari',
            child: fixed
                ? Text(target.label, style: context.text.bodyMedium)
                : DropdownButtonFormField<String>(
                    initialValue: target.key,
                    isExpanded: true,
                    items: [
                      for (final t in targets)
                        DropdownMenuItem(
                          value: t.key,
                          child: Text(
                            '${t.label} · ${formatCardAmount(t.balance)}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _targetKey = v),
                  ),
          ),
          LabeledField(
            label: 'Jumlah',
            child: RupiahField(
              controller: _amount,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              max: _inflow ? null : target.balance,
              maxMessage: 'Melebihi saldo ${formatRupiah(target.balance)}.',
            ),
          ),
          LabeledField(
            label: 'Tanggal',
            child: DateRow(
              value: _date,
              firstDate: target.firstDate,
              onChanged: (d) => setState(() => _date = d),
            ),
          ),
          LabeledField(
            label: 'Catatan (opsional)',
            child: TextFormField(
              controller: _note,
              maxLength: 280,
              decoration: const InputDecoration(
                hintText: 'mis. gaji Oktober',
                counterText: '',
              ),
            ),
          ),
          NoteText(
            _inflow
                ? 'Dicatat sebagai setoran modal: dana disetor bersih naik, '
                      'performa tidak berubah.'
                : 'Dicatat sebagai penarikan modal: dana disetor bersih '
                      'turun, performa tidak berubah.',
          ),
          if (!isSameDate(_date, todayWib()))
            const NoteText(
              'Tanggal mundur tetap masuk ke snapshot berikutnya; snapshot '
              'lama tidak berubah.',
            ),
          const SizedBox(height: AppSpacing.s16),
          BusyButton(
            label: [
              _inflow ? 'Setor' : 'Tarik',
              if (amount != null && amount > Decimal.zero) formatRupiah(amount),
            ].join(' '),
            busy: _busy,
            onPressed: () => _save(target),
          ),
        ],
      ),
    );
  }
}

/// "Set saldo" (PRD A-12a, A-38).
Future<void> showSetBalanceSheet(BuildContext context, Holding holding) =>
    showAppSheet<void>(
      context,
      title: 'Set saldo',
      builder: (_) => _SetBalanceSheet(holding: holding),
    );

class _SetBalanceSheet extends ConsumerStatefulWidget {
  const _SetBalanceSheet({required this.holding});

  final Holding holding;

  @override
  ConsumerState<_SetBalanceSheet> createState() => _SetBalanceSheetState();
}

class _SetBalanceSheetState extends ConsumerState<_SetBalanceSheet> {
  final _form = GlobalKey<FormState>();
  late final _balance = TextEditingController(
    text: groupThousands(widget.holding.qty.toBigInt().toString()),
  );
  DateTime _date = todayWib();
  bool _asIncome = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _balance.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final changed = await ref
          .read(financeActionsProvider)
          .setBalance(
            widget.holding.id,
            balance: parseRupiahInput(_balance.text)!,
            date: _date,
            asIncome: _asIncome,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      if (!changed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saldo sudah sama, tidak ada yang dicatat.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = userMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final next = parseRupiahInput(_balance.text);
    // Display only: the server records the difference from the balance on
    // the chosen date.
    final diff = next == null ? null : next - widget.holding.qty;
    final diffText = diff == null || diff == Decimal.zero
        ? null
        : '${diff > Decimal.zero ? 'Naik' : 'Turun'} '
              '${formatRupiah(diff.abs())} dari saldo sekarang, dicatat '
              'sebagai ${_asIncome ? (diff > Decimal.zero ? 'bunga atau hasil' : 'biaya') : (diff > Decimal.zero ? 'setoran modal' : 'penarikan modal')}.';
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NoteText(
            '${widget.holding.name} · saldo sekarang '
            '${formatRupiah(widget.holding.qty)}',
          ),
          const SizedBox(height: AppSpacing.s16),
          if (_error != null) FormMessage.error(_error!),
          LabeledField(
            label: 'Saldo baru',
            child: RupiahField(
              controller: _balance,
              allowZero: true,
              autofocus: true,
              onChanged: (_) => setState(() {}),
            ),
          ),
          LabeledField(
            label: 'Tanggal',
            child: DateRow(
              value: _date,
              firstDate: widget.holding.startedOn,
              onChanged: (d) => setState(() => _date = d),
            ),
          ),
          Material(
            color: c.surface2,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            clipBehavior: Clip.antiAlias,
            child: CheckboxListTile(
              value: _asIncome,
              onChanged: (v) => setState(() => _asIncome = v ?? false),
              activeColor: c.accent,
              checkColor: c.onAccent,
              title: Text(
                'Selisihnya bunga atau biaya',
                style: context.text.bodyMedium,
              ),
              subtitle: Text(
                'Masuk ke performa. Biarkan mati untuk gaji, belanja, atau '
                'transfer dari luar.',
                style: context.text.bodySmall,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          if (diffText != null) NoteText(diffText),
          const SizedBox(height: AppSpacing.s16),
          BusyButton(label: 'Simpan saldo', busy: _busy, onPressed: _save),
        ],
      ),
    );
  }
}

/// Edit or delete one transaction (PRD F-TX-5).
Future<void> showTransactionSheet(
  BuildContext context,
  CashTransaction tx, {
  required DateTime firstDate,
}) => showAppSheet<void>(
  context,
  title: tx.title,
  builder: (_) => _TransactionSheet(tx: tx, firstDate: firstDate),
);

class _TransactionSheet extends ConsumerStatefulWidget {
  const _TransactionSheet({required this.tx, required this.firstDate});

  final CashTransaction tx;
  final DateTime firstDate;

  @override
  ConsumerState<_TransactionSheet> createState() => _TransactionSheetState();
}

class _TransactionSheetState extends ConsumerState<_TransactionSheet> {
  final _form = GlobalKey<FormState>();
  late final _amount = TextEditingController(
    text: groupThousands(widget.tx.amount.toBigInt().toString()),
  );
  late final _note = TextEditingController(text: widget.tx.note ?? '');
  late DateTime _date = widget.tx.date;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = userMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tx = widget.tx;
    final actions = ref.read(financeActionsProvider);
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NoteText('${tx.holdingName} · ${tx.flowLabel}'),
          const SizedBox(height: AppSpacing.s16),
          if (_error != null) FormMessage.error(_error!),
          LabeledField(
            label: tx.type == TxType.adjust ? 'Selisih' : 'Jumlah',
            child: RupiahField(controller: _amount),
          ),
          LabeledField(
            label: 'Tanggal',
            child: DateRow(
              value: _date,
              firstDate: tx.type == TxType.opening
                  ? DateTime(2000)
                  : widget.firstDate,
              onChanged: (d) => setState(() => _date = d),
            ),
          ),
          LabeledField(
            label: 'Catatan (opsional)',
            child: TextFormField(
              controller: _note,
              maxLength: 280,
              decoration: const InputDecoration(counterText: ''),
            ),
          ),
          if (tx.counted)
            const NoteText(
              'Transaksi ini sudah masuk snapshot. Snapshot lama tidak '
              'berubah; selisihnya dicatat di snapshot berikutnya.',
            ),
          const SizedBox(height: AppSpacing.s16),
          BusyButton(
            label: 'Simpan perubahan',
            busy: _busy,
            onPressed: () {
              if (!_form.currentState!.validate()) return;
              _run(
                () => actions.updateTransaction(
                  tx.id,
                  amount: parseRupiahInput(_amount.text)!,
                  date: _date,
                  note: _note.text,
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.s8),
          TextButton(
            onPressed: _busy
                ? null
                : () => _run(() => actions.deleteTransaction(tx.id)),
            style: TextButton.styleFrom(foregroundColor: c.negative),
            child: const Text('Hapus transaksi'),
          ),
        ],
      ),
    );
  }
}
