import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/geo.dart' as geo;

/// What kind of place to look for around the first stop. Each category is a
/// set of OpenStreetMap tag filters, written in Overpass QL.
enum PlaceCategory {
  pasalubong('Pasalubong', Icons.card_giftcard_outlined, [
    '["shop"~"^(bakery|confectionery|pastry|chocolate|deli|farm|gift|craft)\$"]',
  ], ['bakery', 'gift shop', 'confectionery']),
  restaurant('Restaurants', Icons.restaurant_outlined, [
    '["amenity"~"^(restaurant|fast_food|food_court)\$"]',
  ], ['restaurant', 'fast food']),
  cafe('Cafes', Icons.local_cafe_outlined, ['["amenity"="cafe"]'], ['cafe']),
  bar('Bars', Icons.local_bar_outlined, [
    '["amenity"~"^(bar|pub)\$"]',
  ], ['bar', 'pub']),
  shop('Shops', Icons.storefront_outlined, [
    '["shop"~"^(clothes|books|variety_store|department_store|mall|supermarket|convenience)\$"]',
  ], ['supermarket', 'mall', 'clothes']);

  const PlaceCategory(this.label, this.icon, this.filters, this.searchTerms);
  final String label;
  final IconData icon;

  /// Overpass QL tag filters.
  final List<String> filters;

  /// Plain search words for the Nominatim fallback.
  final List<String> searchTerms;
}

String _pretty(String raw) {
  final first = raw.split(';').first.trim().replaceAll('_', ' ');
  return first.isEmpty ? '' : first[0].toUpperCase() + first.substring(1);
}

class NearbyPlace {
  const NearbyPlace({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    required this.detail,
    required this.isChain,
    this.website = '',
  });

  final String name;
  final double latitude;
  final double longitude;
  final double distanceKm;

  /// Cuisine, shop type or street. May be empty.
  final String detail;

  /// True when OpenStreetMap tags it as part of a brand or chain.
  final bool isChain;

  /// Website from OpenStreetMap, or empty when unknown.
  final String website;

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

    var kind = '';
    for (final key in ['cuisine', 'shop', 'amenity']) {
      final value = tags[key];
      if (value is String && value.isNotEmpty) {
        kind = _pretty(value);
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
      website: cleanUrl(
        tags['website'] ?? tags['contact:website'] ?? tags['url'],
      ),
    );
  }

  /// Builds a place from one Nominatim search result (used when Overpass is
  /// unreachable). Returns null for results without a name.
  static NearbyPlace? fromNominatim(
    Map<String, dynamic> item,
    double originLat,
    double originLon,
  ) {
    final lat = double.tryParse('${item['lat']}');
    final lon = double.tryParse('${item['lon']}');
    final name = (item['name'] as String? ?? '').trim();
    if (lat == null || lon == null || name.isEmpty) return null;

    final extra = (item['extratags'] as Map?)?.cast<String, dynamic>() ?? const {};
    final address = (item['address'] as Map?)?.cast<String, dynamic>() ?? const {};
    final cuisine = extra['cuisine'];
    final type = item['type'] as String? ?? '';
    final kind = cuisine is String && cuisine.isNotEmpty
        ? _pretty(cuisine)
        : (type == 'yes' ? '' : _pretty(type));
    final street = (address['road'] as String?) ?? '';

    return NearbyPlace(
      name: name,
      latitude: lat,
      longitude: lon,
      distanceKm: geo.distanceKm(originLat, originLon, lat, lon),
      detail: [kind, street].where((part) => part.isNotEmpty).join(' · '),
      isChain: extra.containsKey('brand') || extra.containsKey('brand:wikidata'),
      website: cleanUrl(extra['website'] ?? extra['contact:website']),
    );
  }
}
