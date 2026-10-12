import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../core/format/amount_input.dart';
import '../../core/theme/app_typography.dart';

/// Rupiah amount input with live thousand separators.
class RupiahField extends StatelessWidget {
  const RupiahField({
    super.key,
    required this.controller,
    this.allowZero = false,
    this.required = true,
    this.autofocus = false,
    this.onChanged,
    this.max,
    this.maxMessage,
  });

  final TextEditingController controller;
  final bool allowZero;
  final bool required;
  final bool autofocus;
  final ValueChanged<String>? onChanged;

  /// Upper bound, e.g. the balance for a withdrawal.
  final Decimal? max;
  final String? maxMessage;

  String? _validate(String? v) {
    final d = parseRupiahInput(v ?? '');
    if (d == null) return required ? 'Isi jumlahnya.' : null;
    if (d == Decimal.zero && !allowZero) return 'Jumlah harus lebih dari 0.';
    if (max != null && d > max!) return maxMessage ?? 'Melebihi batas.';
    return null;
  }

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    autofocus: autofocus,
    keyboardType: TextInputType.number,
    inputFormatters: const [RupiahInputFormatter()],
    validator: _validate,
    onChanged: onChanged,
    style: context.nums.numLg,
    decoration: const InputDecoration(prefixText: 'Rp ', hintText: '0'),
  );
}
