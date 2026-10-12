import 'package:flutter_test/flutter_test.dart';
import 'package:kekayaanku/core/format/date.dart';

void main() {
  test('short Indonesian date', () {
    expect(formatDateShort(DateTime(2026, 10, 12)), '12 Okt 2026');
    expect(formatDateShort(DateTime(2025, 5, 3)), '3 Mei 2025');
    expect(formatDateShort(DateTime(2027, 8, 31)), '31 Agu 2027');
  });
}
