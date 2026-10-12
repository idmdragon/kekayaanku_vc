import 'package:decimal/decimal.dart';
import 'package:flutter/services.dart';

/// Rupiah typed as `5.000.000`: whole rupiah, dots group thousands.
Decimal? parseRupiahInput(String text) {
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;
  return Decimal.parse(digits);
}

/// Inserts thousand separators while typing and keeps the caret at the end
/// of what was typed.
class RupiahInputFormatter extends TextInputFormatter {
  const RupiahInputFormatter();

  static const int maxDigits = 15;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    digits = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (digits.length > maxDigits) return oldValue;
    final grouped = groupThousands(digits);
    final digitsBeforeCaret = newValue.text
        .substring(0, newValue.selection.end.clamp(0, newValue.text.length))
        .replaceAll(RegExp(r'[^0-9]'), '')
        .length;
    var seen = 0;
    var caret = grouped.length;
    for (var i = 0; i < grouped.length; i++) {
      if (seen == digitsBeforeCaret) {
        caret = i;
        break;
      }
      if (grouped[i] != '.') seen++;
    }
    return TextEditingValue(
      text: grouped,
      selection: TextSelection.collapsed(offset: caret),
    );
  }
}

String groupThousands(String digits) {
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write('.');
    out.write(digits[i]);
  }
  return out.toString();
}
