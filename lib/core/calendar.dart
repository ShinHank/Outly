import '../models/gala.dart';
import 'format.dart';
import 'schedule.dart';

String _stamp(DateTime d) =>
    '${d.year}${two(d.month)}${two(d.day)}T${two(d.hour)}${two(d.minute)}00';
String _day(DateTime d) => '${d.year}${two(d.month)}${two(d.day)}';

String _escape(String text) => text
    .replaceAll(r'\', r'\\')
    .replaceAll(';', r'\;')
    .replaceAll(',', r'\,')
    .replaceAll('\r\n', r'\n')
    .replaceAll('\n', r'\n');

/// Folds long lines at 75 characters, as the iCalendar format requires.
String _fold(String line) {
  if (line.length <= 75) return line;
  final out = StringBuffer(line.substring(0, 75));
  for (var i = 75; i < line.length; i += 74) {
    out
      ..write('\r\n ')
      ..write(line.substring(i, i + 74 > line.length ? line.length : i + 74));
  }
  return out.toString();
}

/// What a calendar needs to know about a gala, independent of file format.
/// Used both by the .ics export and by the direct "add to my calendar" flow.
class CalendarEntry {
  const CalendarEntry({
    required this.title,
    required this.description,
    required this.location,
    required this.start,
    required this.end,
    required this.allDay,
  });

  final String title;
  final String description;
  final String location;
  final DateTime start;

  /// For all-day entries this is the last day itself (inclusive).
  final DateTime end;
  final bool allDay;
}

/// A one-day gala whose stops have times becomes a timed entry running from
/// the first to the last timed stop. Everything else is an all-day entry
/// covering each day of the outing. The itinerary goes in the description.
CalendarEntry galaToCalendarEntry(Gala gala, {List<String> guests = const []}) {
  final (start, end, allDay) = _slot(gala);
  final places = gala.places;
  return CalendarEntry(
    title: gala.name.isEmpty ? 'Outly gala' : gala.name,
    description: _description(gala, guests),
    location: places.isNotEmpty ? places.first.name : gala.location,
    start: start,
    end: end,
    allDay: allDay,
  );
}

String _description(Gala gala, List<String> guests) {
  final places = gala.places;
  final start = DateTime(gala.date.year, gala.date.month, gala.date.day);
  final days = gala.dayCount;
  final description = StringBuffer();
  for (var i = 0; i < places.length; i++) {
    final stop = places[i];
    final when = [
      if (days > 1) 'Day ${stopDay(stop, start) + 1}',
      if (stop.time.isNotEmpty) timeLabel(stop.time),
    ].join(' ');
    description.writeln('${i + 1}. ${when.isEmpty ? '' : '$when - '}${stop.name}');
  }
  if (guests.isNotEmpty) {
    description
      ..writeln()
      ..writeln("Who's coming: ${guests.join(', ')}");
  }
  if (gala.plan.trim().isNotEmpty) {
    description
      ..writeln()
      ..writeln(gala.plan.trim());
  }
  return description.toString().trim();
}

/// (start, inclusive end, allDay). Timed only for one-day galas with times.
(DateTime, DateTime, bool) _slot(Gala gala) {
  final start = DateTime(gala.date.year, gala.date.month, gala.date.day);
  final days = gala.dayCount;
  final times = [
    for (final stop in gala.places)
      if (parseTime(stop.time) != null) parseTime(stop.time)!,
  ].map((t) => t.hour * 60 + t.minute).toList()..sort();

  if (days == 1 && times.isNotEmpty) {
    final from = start.add(Duration(minutes: times.first));
    var to = start.add(Duration(minutes: times.last + 60));
    if (!to.isAfter(from)) to = from.add(const Duration(hours: 1));
    return (from, to, false);
  }
  return (start, addDays(start, days - 1), true);
}

/// Builds an iCalendar (.ics) file for a gala. Any calendar app can import it,
/// which makes it the format to hand to friends.
String galaToIcs(Gala gala, {List<String> guests = const []}) {
  final places = gala.places;
  final start = DateTime(gala.date.year, gala.date.month, gala.date.day);
  final days = gala.dayCount;
  final (from, to, allDay) = _slot(gala);

  final lines = <String>[
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Outly//Gala planner//EN',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    'BEGIN:VEVENT',
    'UID:${gala.id}@outly.app',
    'DTSTAMP:${_stamp(DateTime.now().toUtc())}Z',
  ];
  if (!allDay) {
    lines
      ..add('DTSTART:${_stamp(from)}')
      ..add('DTEND:${_stamp(to)}');
  } else {
    lines
      ..add('DTSTART;VALUE=DATE:${_day(start)}')
      // The end date of an all-day event is exclusive.
      ..add('DTEND;VALUE=DATE:${_day(addDays(start, days))}');
  }
  lines.add('SUMMARY:${_escape(gala.name.isEmpty ? 'Outly gala' : gala.name)}');
  final where = places.isNotEmpty ? places.first.name : gala.location;
  if (where.trim().isNotEmpty) lines.add('LOCATION:${_escape(where)}');
  final first = places.isNotEmpty ? places.first : null;
  if (first != null && (first.latitude != 0 || first.longitude != 0)) {
    lines.add('GEO:${first.latitude};${first.longitude}');
  }
  final text = _description(gala, guests);
  if (text.isNotEmpty) lines.add('DESCRIPTION:${_escape(text)}');
  lines
    ..add('STATUS:${gala.status == 'Cancelled' ? 'CANCELLED' : 'CONFIRMED'}')
    // Reminder one day before.
    ..add('BEGIN:VALARM')
    ..add('ACTION:DISPLAY')
    ..add('DESCRIPTION:${_escape(gala.name)}')
    ..add('TRIGGER:-P1D')
    ..add('END:VALARM')
    ..add('END:VEVENT')
    ..add('END:VCALENDAR');
  return '${lines.map(_fold).join('\r\n')}\r\n';
}
