import '../models/location.dart';
import 'format.dart';

/// Which day of the outing a stop belongs to, 0-based. Stops without a date
/// (and any that fall outside the outing) count as the first day.
int stopDay(GalaLocation stop, DateTime start) {
  final parsed = DateTime.tryParse(stop.date);
  if (parsed == null) return 0;
  final a = DateTime.utc(start.year, start.month, start.day);
  final b = DateTime.utc(parsed.year, parsed.month, parsed.day);
  final days = b.difference(a).inDays;
  return days < 0 ? 0 : days;
}

int _minutes(String time) {
  final t = parseTime(time);
  // Stops without a time go to the end of their day.
  return t == null ? 24 * 60 + 1 : t.hour * 60 + t.minute;
}

/// Orders stops by day, then by time. Stops with the same day and time (or no
/// time) keep the order they were added in.
List<GalaLocation> sortStops(List<GalaLocation> stops, DateTime start) {
  final indexed = [for (var i = 0; i < stops.length; i++) (i, stops[i])];
  indexed.sort((a, b) {
    final day = stopDay(a.$2, start).compareTo(stopDay(b.$2, start));
    if (day != 0) return day;
    final time = _minutes(a.$2.time).compareTo(_minutes(b.$2.time));
    if (time != 0) return time;
    return a.$1.compareTo(b.$1);
  });
  return [for (final item in indexed) item.$2];
}
