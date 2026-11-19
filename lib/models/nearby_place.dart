import 'package:flutter/material.dart';

import '../core/geo.dart' as geo;

/// What kind of place to look for around the first stop. Each category is a
/// set of OpenStreetMap tag filters, written in Overpass QL.
enum PlaceCategory {
  pasalubong('Pasalubong', Icons.card_giftcard_outlined, [
    '["shop"~"^(bakery|confectionery|pastry|chocolate|deli|farm|gift|craft)\$"]',
  ]),
  restaurant('Restaurants', Icons.restaurant_outlined, [
    '["amenity"~"^(restaurant|fast_food|food_court)\$"]',
  ]),
  cafe('Cafes', Icons.local_cafe_outlined, ['["amenity"="cafe"]']),
  bar('Bars', Icons.local_bar_outlined, ['["amenity"~"^(bar|pub)\$"]']),
  shop('Shops', Icons.storefront_outlined, [
    '["shop"~"^(clothes|books|variety_store|department_store|mall|supermarket|convenience)\$"]',
  ]);

  const PlaceCategory(this.label, this.icon, this.filters);
  final String label;
  final IconData icon;
  final List<String> filters;
}

class NearbyPlace {
  const NearbyPlace({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    required this.detail,
    required this.isChain,
  });

  final String name;
  final double latitude;
  final double longitude;
  final double distanceKm;

  /// Cuisine, shop type or street. May be empty.
  final String detail;

  /// True when OpenStreetMap tags it as part of a brand or chain.
  final bool isChain;

  /// Builds a place from one Overpass element. Returns null for unnamed
  /// places or ones without coordinates.
  static NearbyPlace? fromOverpass(
    Map<String, dynamic> element,
    double originLat,
    double originLon,
  ) {
    final tags = (element['tags'] as Map?)?.cast<String, dynamic>() ?? const {};
    final name = (tags['name'] as String? ?? '').trim();
    if (name.isEmpty) return null;

    final center = element['center'] as Map?;
    final lat = ((element['lat'] ?? center?['lat']) as num?)?.toDouble();
    final lon = ((element['lon'] ?? center?['lon']) as num?)?.toDouble();
    if (lat == null || lon == null) return null;

    String pretty(String raw) {
      final first = raw.split(';').first.trim().replaceAll('_', ' ');
      return first.isEmpty ? '' : first[0].toUpperCase() + first.substring(1);
    }

    var kind = '';
    for (final key in ['cuisine', 'shop', 'amenity']) {
      final value = tags[key];
      if (value is String && value.isNotEmpty) {
        kind = pretty(value);
        break;
      }
    }
    final street = (tags['addr:street'] as String?) ?? '';
    final detail = [kind, street].where((part) => part.isNotEmpty).join(' · ');

    return NearbyPlace(
      name: name,
      latitude: lat,
      longitude: lon,
      distanceKm: geo.distanceKm(originLat, originLon, lat, lon),
      detail: detail,
      isChain: tags.containsKey('brand') || tags.containsKey('brand:wikidata'),
    );
  }
}
