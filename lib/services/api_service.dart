import 'dart:convert';

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

  Future<List<LocationSuggestion>> searchLocations(String query) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': query,
      'format': 'jsonv2',
      'limit': '5',
      'addressdetails': '1',
      'email': contactEmail,
    });
    final response = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
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
          );
        })
        .where((item) => item.latitude != 0 && item.longitude != 0)
        .toList();
  }

  /// Best-effort place name for a map pin. Returns null if nothing useful.
  Future<String?> reverseGeocode(double lat, double lon) async {
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
    if (response.statusCode != 200) return null;
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
  }) async {
    final clauses = category.filters
        .map((filter) => '  nwr$filter(around:$radiusMeters,$lat,$lon);')
        .join('\n');
    final query = '[out:json][timeout:20];\n(\n$clauses\n);\nout center 100;';
    final uri = Uri.https('overpass-api.de', '/api/interpreter');
    final response = await http
        .post(uri, headers: _headers, body: {'data': query})
        .timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Nearby search failed (HTTP ${response.statusCode})',
        uri,
      );
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final seen = <String>{};
    final places = <NearbyPlace>[];
    for (final element in (json['elements'] as List? ?? [])) {
      final place = NearbyPlace.fromOverpass(
        (element as Map).cast<String, dynamic>(),
        lat,
        lon,
      );
      if (place == null) continue;
      // The same shop can be mapped as both a point and a building.
      if (!seen.add('${place.name.toLowerCase()}|${place.latitude.toStringAsFixed(3)}|${place.longitude.toStringAsFixed(3)}')) {
        continue;
      }
      places.add(place);
    }
    places.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return places;
  }

  /// Daily weather for [date] at the given coordinates, via Open-Meteo.
  /// No API key. Returns null when the date is too far ahead to forecast.
  Future<WeatherInfo?> fetchWeather(
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
