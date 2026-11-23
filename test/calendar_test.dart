import 'package:flutter_test/flutter_test.dart';

import '../lib/core/calendar.dart';
import '../lib/models/gala.dart';
import '../lib/models/location.dart';

GalaLocation stop(String name, {String time = '', String date = ''}) =>
    GalaLocation(name: name, latitude: 14.6, longitude: 121, time: time, date: date);

void main() {
  test('one-day gala with times becomes a timed event', () {
    final ics = galaToIcs(Gala(
      name: 'Food trip',
      date: DateTime(2026, 11, 20),
      location: 'Cubao',
      locations: [stop('Cafe', time: '09:00'), stop('Dinner, Cubao', time: '18:30')],
    ));
    expect(ics, contains('DTSTART:20261120T090000'));
    expect(ics, contains('DTEND:20261120T193000'));
    expect(ics, contains('SUMMARY:Food trip'));
    expect(ics, contains(r'Dinner\, Cubao'));
    expect(ics, contains('BEGIN:VCALENDAR'));
  });

  test('multi-day gala is all-day with an exclusive end date', () {
    final ics = galaToIcs(Gala(
      name: 'Staycation',
      date: DateTime(2026, 11, 20),
      endDate: DateTime(2026, 11, 22),
      location: 'Hotel',
      locations: [stop('Hotel'), stop('Mall', date: '2026-11-21')],
    ));
    expect(ics, contains('DTSTART;VALUE=DATE:20261120'));
    expect(ics, contains('DTEND;VALUE=DATE:20261123'));
  });

  test('calendar entry matches the ics timing', () {
    final timed = galaToCalendarEntry(Gala(
      name: 'Food trip',
      date: DateTime(2026, 11, 20),
      location: 'Cubao',
      locations: [stop('Cafe', time: '09:00'), stop('Dinner', time: '18:30')],
    ));
    expect(timed.allDay, isFalse);
    expect(timed.start, DateTime(2026, 11, 20, 9));
    expect(timed.end, DateTime(2026, 11, 20, 19, 30));

    final multi = galaToCalendarEntry(Gala(
      name: 'Staycation',
      date: DateTime(2026, 11, 20),
      endDate: DateTime(2026, 11, 22),
      location: 'Hotel',
      locations: [stop('Hotel')],
    ));
    expect(multi.allDay, isTrue);
    expect(multi.end, DateTime(2026, 11, 22));
  });
}
