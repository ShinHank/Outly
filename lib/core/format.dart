import 'package:flutter/material.dart';

import 'constants.dart';

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
String dateText(DateTime d) => '${d.month}/${d.day}/${d.year}';
String two(int n) => n.toString().padLeft(2, '0');
String ymd(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';
String money(double v) => '$currency${v.toStringAsFixed(2)}';

/// Whole days from today until [d] (negative when in the past).
int daysUntil(DateTime d) {
  final now = DateTime.now();
  return DateTime(d.year, d.month, d.day)
      .difference(DateTime(now.year, now.month, now.day))
      .inDays;
}

String countdown(DateTime d) {
  final n = daysUntil(d);
  if (n == 0) return 'Today';
  if (n == 1) return 'Tomorrow';
  if (n > 1) return 'In $n days';
  if (n == -1) return 'Yesterday';
  return '${-n} days ago';
}

/// Stop times are stored as 24h "HH:mm" strings. Empty means no time.
TimeOfDay? parseTime(String t) {
  final parts = t.split(':');
  if (parts.length != 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  return TimeOfDay(hour: h, minute: m);
}

String formatTime(TimeOfDay t) => '${two(t.hour)}:${two(t.minute)}';

String timeLabel(String t) {
  final p = parseTime(t);
  if (p == null) return '';
  final h = p.hour % 12 == 0 ? 12 : p.hour % 12;
  return '$h:${two(p.minute)} ${p.hour < 12 ? 'AM' : 'PM'}';
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
String longDate(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${_months[d.month - 1]} ${d.day}, ${d.year}';
String shortDate(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${_months[d.month - 1]} ${d.day}';

/// "Jollibee, Aguinaldo Highway, Kawit, ..." -> "Jollibee".
String shortName(String full) {
  final parts = full
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return full;
  final first = parts.first;
  final looksLikeNumber = RegExp(r'^[\d\s\-/]+$').hasMatch(first);
  if (looksLikeNumber && parts.length > 1) return '$first ${parts[1]}';
  return first;
}

String planFileName(String name) {
  final base = name.trim().isEmpty
      ? 'gala'
      : name.trim().replaceAll(RegExp(r'\s+'), '_');
  return '${base}_plan.png';
}

DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

/// "11/20/2026" for one day, "11/20/2026 – 11/22/2026" for a range.
String dateRangeText(DateTime start, DateTime? end) =>
    end == null || sameDay(start, end)
    ? dateText(start)
    : '${dateText(start)} – ${dateText(end)}';

/// "Fri, Nov 20, 2026" or "Fri, Nov 20 – Sun, Nov 22, 2026".
String longDateRange(DateTime start, DateTime? end) =>
    end == null || sameDay(start, end)
    ? longDate(start)
    : '${shortDate(start)} – ${shortDate(end)}, ${end.year}';

/// "Fri, Nov 20" or "Fri, Nov 20 – Sun, Nov 22".
String shortDateRange(DateTime start, DateTime? end) =>
    end == null || sameDay(start, end)
    ? shortDate(start)
    : '${shortDate(start)} – ${shortDate(end)}';

/// "Today", "In 3 days", or "Happening now" while a multi-day outing runs.
String whenLabel(DateTime start, DateTime? end) {
  final last = end ?? start;
  if (daysUntil(start) < 0 && daysUntil(last) >= 0) return 'Happening now';
  return countdown(start);
}

/// "Day 2 · Sat, Nov 21" for the [index]th day (0-based) of an outing.
String dayLabel(int index, DateTime start) =>
    'Day ${index + 1} · ${shortDate(addDays(start, index))}';

/// Turns an OpenStreetMap website tag into a usable https URL, or '' if empty.
String cleanUrl(Object? raw) {
  if (raw is! String) return '';
  var url = raw.split(';').first.trim();
  if (url.isEmpty) return '';
  if (!url.startsWith('http://') && !url.startsWith('https://')) {
    url = 'https://$url';
  }
  return url;
}
