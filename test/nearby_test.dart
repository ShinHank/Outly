import 'package:flutter_test/flutter_test.dart';

import '../lib/core/geo.dart';
import '../lib/models/nearby_place.dart';

void main() {
  const lat = 14.5995, lon = 120.9842;

  test('parses a named point', () {
    final p = NearbyPlace.fromOverpass({
      'lat': 14.6005,
      'lon': 120.9842,
      'tags': {'name': 'Tindahan ni Aling Rosa', 'shop': 'bakery'},
    }, lat, lon)!;
    expect(p.name, 'Tindahan ni Aling Rosa');
    expect(p.detail, 'Bakery');
    expect(p.isChain, isFalse);
    expect(p.distanceKm, closeTo(0.11, 0.02));
  });

  test('uses center for buildings and reads cuisine and street', () {
    final p = NearbyPlace.fromOverpass({
      'center': {'lat': 14.6, 'lon': 120.985},
      'tags': {
        'name': 'Lutong Bahay',
        'amenity': 'restaurant',
        'cuisine': 'filipino;seafood',
        'addr:street': 'Rizal St',
      },
    }, lat, lon)!;
    expect(p.detail, 'Filipino · Rizal St');
  });

  test('flags branded places as chains', () {
    final p = NearbyPlace.fromOverpass({
      'lat': 14.6,
      'lon': 120.98,
      'tags': {'name': 'Big Chain', 'amenity': 'cafe', 'brand': 'Big Chain'},
    }, lat, lon)!;
    expect(p.isChain, isTrue);
  });

  test('skips unnamed places and places without coordinates', () {
    expect(
      NearbyPlace.fromOverpass({'lat': 1.0, 'lon': 1.0, 'tags': {'shop': 'gift'}}, lat, lon),
      isNull,
    );
    expect(
      NearbyPlace.fromOverpass({'tags': {'name': 'Nowhere'}}, lat, lon),
      isNull,
    );
  });

  test('distance helpers', () {
    expect(distanceKm(14, 121, 15, 121), closeTo(111.2, 0.5));
    expect(distanceLabel(0.25), '250 m');
    expect(distanceLabel(2.34), '2.3 km');
  });

  test('parses a Nominatim result and flags brands', () {
    final p = NearbyPlace.fromNominatim({
      'lat': '14.6005',
      'lon': '120.9842',
      'name': 'Aling Rosa Bakery',
      'type': 'bakery',
      'address': {'road': 'Rizal St'},
      'extratags': <String, dynamic>{},
    }, lat, lon)!;
    expect(p.detail, 'Bakery · Rizal St');
    expect(p.isChain, isFalse);

    final chain = NearbyPlace.fromNominatim({
      'lat': '14.6',
      'lon': '120.98',
      'name': 'Big Chain',
      'type': 'cafe',
      'extratags': {'brand': 'Big Chain'},
    }, lat, lon)!;
    expect(chain.isChain, isTrue);

    expect(
      NearbyPlace.fromNominatim({'lat': '1', 'lon': '1', 'type': 'road'}, lat, lon),
      isNull,
    );
  });
}
