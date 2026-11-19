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
