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
