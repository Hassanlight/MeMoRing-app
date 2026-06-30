/// User-facing time formatting (no intl dependency for v1; rounded + friendly).
library;

String _two(int n) => n.toString().padLeft(2, '0');

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "4:30 PM"
String formatClock(DateTime d) {
  final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final period = d.hour < 12 ? 'AM' : 'PM';
  return '$hour12:${_two(d.minute)} $period';
}

/// "today · 4:30 PM" / "tomorrow 9:00 AM" / "Jun 30 · 9:00 AM"
String formatWhen(DateTime fireAt, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(fireAt.year, fireAt.month, fireAt.day);
  final diffDays = day.difference(today).inDays;
  final clock = formatClock(fireAt);
  if (diffDays == 0) return 'today · $clock';
  if (diffDays == 1) return 'tomorrow · $clock';
  return '${_months[fireAt.month - 1]} ${fireAt.day} · $clock';
}

/// Short relative emphasis: "in 2 hours", "in 3 days", "overdue".
String formatRelative(DateTime fireAt, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final diff = fireAt.difference(n);
  if (diff.isNegative) return 'overdue';
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return 'in ${diff.inMinutes} min';
  if (diff.inHours < 24) {
    final h = diff.inHours;
    return 'in $h ${h == 1 ? 'hour' : 'hours'}';
  }
  if (diff.inDays < 30) {
    final d = diff.inDays;
    return 'in $d ${d == 1 ? 'day' : 'days'}';
  }
  final months = (diff.inDays / 30).round();
  return 'in $months ${months == 1 ? 'month' : 'months'}';
}
