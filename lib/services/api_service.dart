import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../core/format.dart';
import '../models/location.dart';
import '../models/nearby_place.dart';
import '../models/weather_info.dart';

class ApiService {
  final _headers = const {
    'User-Agent': 'Outly/1.0 ($contactEmail)',
    'Accept-Language': 'en',
  };

  static String _short(String body) =>
      body.length > 300 ? body.substring(0, 300) : body;

  /// Runs [body] and prints any failure to the console (Android Studio's Run
  /// or Debug tab) before passing it on. Filter the console by "[Outly API]".
  Future<T> _guard<T>(String name, Future<T> Function() body) async {
    try {
      return await body();
    } catch (e, stack) {
      debugPrint('[Outly API] $name failed: ${e.runtimeType}: $e');
      debugPrintStack(stackTrace: stack, maxFrames: 4, label: '[Outly API] $name');
      rethrow;
    }
  }

  Future<List<LocationSuggestion>> searchLocations(String query) =>
      _guard('searchLocations("$query")', () => _searchLocations(query));

  Future<List<LocationSuggestion>> _searchLocations(String query) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': query,
      'format': 'jsonv2',
      'limit': '5',
      'addressdetails': '1',
      'extratags': '1',
      'email': contactEmail,
    });
    final response = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      debugPrint('[Outly API] search body: ${_short(response.body)}');
      throw http.ClientException(
        'Location search failed (HTTP ${response.statusCode})',
        uri,
      );
    }
    final list = jsonDecode(response.body) as List;
    return list
        .map((item) {
          final result = item as Map<String, dynamic>;
          return LocationSuggestion(
            name: result['display_name'] as String? ?? '',
            latitude: double.tryParse(result['lat']?.toString() ?? '') ?? 0,
            longitude: double.tryParse(result['lon']?.toString() ?? '') ?? 0,
            website: cleanUrl(
              (result['extratags'] as Map?)?['website'] ??
                  (result['extratags'] as Map?)?['contact:website'],
            ),
          );
        })
        .where((item) => item.latitude != 0 && item.longitude != 0)
        .toList();
  }

  /// Best-effort place name for a map pin. Returns null if nothing useful.
  Future<String?> reverseGeocode(double lat, double lon) =>
      _guard('reverseGeocode($lat, $lon)', () => _reverseGeocode(lat, lon));

  Future<String?> _reverseGeocode(double lat, double lon) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'lat': '$lat',
      'lon': '$lon',
      'format': 'jsonv2',
      'zoom': '18',
      'email': contactEmail,
    });
    final response = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      debugPrint('[Outly API] reverseGeocode: HTTP ${response.statusCode} ${response.body}');
      return null;
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final name = (json['name'] as String? ?? '').trim();
    if (name.isNotEmpty) return name;
    final display = json['display_name'] as String? ?? '';
    final short = display
        .split(',')
        .take(2)
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .join(', ');
    return short.isEmpty ? null : short;
  }

  /// Named places of one [category] around a point, nearest first, from
  /// OpenStreetMap via the free Overpass API (no key needed).
  Future<List<NearbyPlace>> nearbyPlaces(
    double lat,
    double lon,
    PlaceCategory category, {
    int radiusMeters = 1500,
  }) => _guard(
    'nearbyPlaces(${category.name}, $lat, $lon)',
    () => _nearbyPlaces(lat, lon, category, radiusMeters),
  );

  Future<List<NearbyPlace>> _nearbyPlaces(
    double lat,
    double lon,
    PlaceCategory category,
    int radiusMeters,
  ) async {
    List<NearbyPlace> places;
    try {
      places = await _overpass(lat, lon, category, radiusMeters);
    } catch (overpassError) {
      // Overpass is a shared public server and is often slow or blocked, so
      // fall back to Nominatim, which the location search already uses.
      debugPrint('[Outly API] Overpass failed, trying Nominatim: $overpassError');
      try {
        places = await _nominatimNearby(lat, lon, category, radiusMeters);
      } catch (nominatimError) {
        throw http.ClientException(
          'Nearby search failed. Overpass: $overpassError. Nominatim: $nominatimError',
          Uri.https('overpass-api.de', '/api/interpreter'),
        );
      }
    }
    final seen = <String>{};
    final unique = <NearbyPlace>[];
    for (final place in places) {
      // The same shop can be mapped as both a point and a building.
      final key =
          '${place.name.toLowerCase()}|${place.latitude.toStringAsFixed(3)}|${place.longitude.toStringAsFixed(3)}';
      if (seen.add(key)) unique.add(place);
    }
    unique.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return unique;
  }

  Future<List<NearbyPlace>> _overpass(
    double lat,
    double lon,
    PlaceCategory category,
    int radiusMeters,
  ) async {
    final clauses = category.filters
        .map((filter) => '  nwr$filter(around:$radiusMeters,$lat,$lon);')
        .join('\n');
    final query = '[out:json][timeout:10];\n(\n$clauses\n);\nout center 60;';
    final uri = Uri.https('overpass-api.de', '/api/interpreter');
    final response = await http
        .post(uri, headers: _headers, body: {'data': query})
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      debugPrint('[Outly API] overpass body: ${_short(response.body)}');
      throw http.ClientException('HTTP ${response.statusCode}', uri);
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final places = <NearbyPlace>[];
    for (final element in (json['elements'] as List? ?? [])) {
      final place = NearbyPlace.fromOverpass(
        (element as Map).cast<String, dynamic>(),
        lat,
        lon,
      );
      if (place != null) places.add(place);
    }
    return places;
  }

  /// Fallback: Nominatim "restaurant in this box" style searches.
  Future<List<NearbyPlace>> _nominatimNearby(
    double lat,
    double lon,
    PlaceCategory category,
    int radiusMeters,
  ) async {
    final dLat = radiusMeters / 111000.0;
    final dLon = dLat / math.cos(lat * math.pi / 180);
    final box = '${lon - dLon},${lat + dLat},${lon + dLon},${lat - dLat}';
    final out = <NearbyPlace>[];
    for (var i = 0; i < category.searchTerms.length; i++) {
      // Nominatim's usage policy allows at most one request per second.
      if (i > 0) await Future<void>.delayed(const Duration(milliseconds: 1100));
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': category.searchTerms[i],
        'format': 'jsonv2',
        'viewbox': box,
        'bounded': '1',
        'limit': '40',
        'addressdetails': '1',
        'extratags': '1',
        'email': contactEmail,
      });
      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        debugPrint('[Outly API] nominatim body: ${_short(response.body)}');
        throw http.ClientException('HTTP ${response.statusCode}', uri);
      }
      for (final item in jsonDecode(response.body) as List) {
        final place = NearbyPlace.fromNominatim(
          (item as Map).cast<String, dynamic>(),
          lat,
          lon,
        );
        if (place != null) out.add(place);
      }
    }
    return out;
  }

  /// Daily weather for [date] at the given coordinates, via Open-Meteo.
  /// No API key. Returns null when the date is too far ahead to forecast.
  Future<WeatherInfo?> fetchWeather(double lat, double lon, DateTime date) =>
      _guard(
        'fetchWeather($lat, $lon, ${ymd(date)})',
        () => _fetchWeather(lat, lon, date),
      );

  Future<WeatherInfo?> _fetchWeather(
    double lat,
    double lon,
    DateTime date,
  ) async {
    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    final day = DateTime.utc(date.year, date.month, date.day);
    final diff = day.difference(today).inDays;
    if (diff > 15) return null;

    final dateKey = ymd(day);
    final Uri uri;
    if (diff >= -91) {
      // Forecast API covers 92 past days and 16 days ahead. We ask for a
      // window and pick the right day by its date, so timezone offsets
      // between the phone and the location don't matter.
      final pastDays = diff < 0 ? -diff + 1 : 1;
      final forecastDays = diff > 0 ? (diff + 2).clamp(1, 16) : 2;
      uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': '$lat',
        'longitude': '$lon',
        'daily':
            'weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max',
        'timezone': 'auto',
        'past_days': '$pastDays',
        'forecast_days': '$forecastDays',
      });
    } else {
      uri = Uri.https('archive-api.open-meteo.com', '/v1/archive', {
        'latitude': '$lat',
        'longitude': '$lon',
        'start_date': dateKey,
        'end_date': dateKey,
        'daily': 'weather_code,temperature_2m_max,temperature_2m_min',
        'timezone': 'auto',
      });
    }

    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      debugPrint('[Outly API] weather body: ${_short(response.body)}');
      throw http.ClientException(
        'Weather lookup failed (HTTP ${response.statusCode})',
        uri,
      );
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final daily = json['daily'] as Map<String, dynamic>?;
    if (daily == null) return null;
    final index = ((daily['time'] as List?) ?? []).indexOf(dateKey);
    if (index < 0) return null;

    num? at(String key) {
      final list = daily[key] as List?;
      if (list == null || index >= list.length) return null;
      return list[index] as num?;
    }

    final code = at('weather_code');
    final hi = at('temperature_2m_max');
    final lo = at('temperature_2m_min');
    if (code == null || hi == null || lo == null) return null;
    return WeatherInfo(
      code: code.toInt(),
      max: hi.toDouble(),
      min: lo.toDouble(),
      rainChance: at('precipitation_probability_max')?.round(),
    );
  }
}
