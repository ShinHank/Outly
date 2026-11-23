import 'package:flutter_test/flutter_test.dart';

import '../lib/core/schedule.dart';
import '../lib/models/gala.dart';
import '../lib/models/location.dart';

GalaLocation stop(String name, {String time = '', String date = ''}) =>
    GalaLocation(name: name, latitude: 14.6, longitude: 121, time: time, date: date);

void main() {
  final start = DateTime(2026, 11, 20);

  test('stops sort by time within a day, untimed stops last', () {
    final sorted = sortStops([
      stop('Dinner', time: '19:00'),
      stop('No time'),
      stop('Breakfast', time: '08:30'),
    ], start);
    expect(sorted.map((s) => s.name), ['Breakfast', 'Dinner', 'No time']);
  });

  test('earlier days come before later days regardless of time', () {
    final sorted = sortStops([
      stop('Mall brunch', time: '09:00', date: '2026-11-21'),
      stop('Hotel check-in', time: '15:00'),
    ], start);
    expect(sorted.map((s) => s.name), ['Hotel check-in', 'Mall brunch']);
  });

  test('equal times keep the order they were added', () {
    final sorted = sortStops([
      stop('A', time: '10:00'),
      stop('B', time: '10:00'),
    ], start);
    expect(sorted.map((s) => s.name), ['A', 'B']);
  });

  test('stopDay clamps unknown and earlier dates to day one', () {
    expect(stopDay(stop('x'), start), 0);
    expect(stopDay(stop('x', date: '2026-11-22'), start), 2);
    expect(stopDay(stop('x', date: '2026-11-01'), start), 0);
  });

  test('multi-day gala reports its length and overlaps', () {
    final trip = Gala(
      name: 'Staycation',
      date: DateTime(2026, 11, 20),
      endDate: DateTime(2026, 11, 22),
      location: '',
    );
    expect(trip.dayCount, 3);
    expect(trip.isMultiDay, isTrue);
    final dinner = Gala(name: 'Dinner', date: DateTime(2026, 11, 22), location: '');
    final later = Gala(name: 'Later', date: DateTime(2026, 11, 23), location: '');
    expect(trip.overlaps(dinner), isTrue);
    expect(trip.overlaps(later), isFalse);
  });

  test('older galas without an end date are single-day', () {
    final g = Gala.fromJson({'name': 'Old', 'scheduledDate': '2026-11-20T00:00:00.000'});
    expect(g.endDate, isNull);
    expect(g.dayCount, 1);
  });
}
