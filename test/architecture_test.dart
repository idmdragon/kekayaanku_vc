import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the CLAUDE.md UI rules that a reviewer would otherwise check by eye.
void main() {
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('colours come only from lib/core/theme', () {
    final offenders = [
      for (final f in files)
        if (!f.path.contains('core/theme/') &&
            RegExp(r'\bColors\.|Color\(0x').hasMatch(f.readAsStringSync()))
          f.path,
    ];
    expect(offenders, isEmpty);
  });

  test('only app_icons.dart imports the icon package', () {
    final offenders = [
      for (final f in files)
        if (!f.path.endsWith('app_icons.dart') &&
            f.readAsStringSync().contains('lucide_icons_flutter'))
          f.path,
    ];
    expect(offenders, isEmpty);
  });

  test('money is never a double', () {
    final offenders = [
      // Theme tint amounts are doubles by nature; money lives elsewhere.
      for (final f in files)
        if (!f.path.contains('core/theme/') &&
            RegExp(
              r'double\s+\w*(amount|price|value|cash|cost)',
              caseSensitive: false,
            ).hasMatch(f.readAsStringSync()))
          f.path,
    ];
    expect(offenders, isEmpty);
  });
}
