/// Short Indonesian dates without locale data: `12 Okt 2026`.
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

String formatDateShort(DateTime d) =>
    '${d.day} ${_months[d.month - 1]} ${d.year}';

const _weekdays = [
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
  'Minggu',
];

const _monthsLong = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

/// `Senin`.
String formatWeekday(DateTime d) => _weekdays[d.weekday - 1];

/// `Oktober 2026`.
String formatMonthYear(DateTime d) => '${_monthsLong[d.month - 1]} ${d.year}';

/// `12 Okt`.
String formatDayMonth(DateTime d) => '${d.day} ${_months[d.month - 1]}';

/// Today's business date: the calendar date in WIB (UTC+7), whatever the
/// device's time zone (CLAUDE.md).
DateTime todayWib([DateTime? now]) {
  final t = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 7));
  return DateTime(t.year, t.month, t.day);
}

bool isSameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
