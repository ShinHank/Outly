import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

const rose = Color(0xFFB85C72);
const plum = Color(0xFF4A2633);
const cream = Color(0xFFFFF8F5);

/// Nominatim's usage policy asks for a real contact. Put your own here.
const contactEmail = 'slimedipz@gmail.com';

/// Where the pin map opens when a gala has no locations yet.
const defaultMapCenter = LatLng(14.5995, 120.9842);

/// One-tap outing types. Users can also add their own.
const suggestedTags = [
  'Dinner',
  'Drinks',
  'Coffee',
  'Brunch',
  'Staycation',
  'Beach',
  'Hike',
  'Road trip',
  'Karaoke',
  'Movie night',
  'Shopping',
  'Party',
];

void main() => runApp(const OutlyApp());

class OutlyApp extends StatelessWidget {
  const OutlyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Outly',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: rose),
      scaffoldBackgroundColor: cream,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    ),
    home: const HomeScreen(),
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
String dateText(DateTime d) => '${d.month}/${d.day}/${d.year}';
String two(int n) => n.toString().padLeft(2, '0');
String ymd(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';

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

/// Renders a RepaintBoundary to PNG bytes at a fixed pixel width, so exports
/// look the same on every device.
Future<Uint8List?> capturePng(GlobalKey key, {required double width}) async {
  final boundary =
  key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return null;
  await WidgetsBinding.instance.endOfFrame;
  final ratio = width / boundary.size.width;
  final image = await boundary.toImage(pixelRatio: ratio);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data?.buffer.asUint8List();
}

IconData weatherIconFor(int code) => switch (code) {
  0 || 1 => Icons.wb_sunny_outlined,
  2 => Icons.cloud_queue,
  3 || 45 || 48 => Icons.cloud_outlined,
  51 ||
  53 ||
  55 ||
  56 ||
  57 ||
  61 ||
  63 ||
  65 ||
  66 ||
  67 ||
  80 ||
  81 ||
  82 => Icons.umbrella_outlined,
  71 || 73 || 75 || 77 || 85 || 86 => Icons.ac_unit,
  95 || 96 || 99 => Icons.thunderstorm_outlined,
  _ => Icons.cloud_outlined,
};

Widget section(String title, List<Widget> children) => Padding(
  padding: const EdgeInsets.only(top: 20),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          color: plum,
          fontWeight: FontWeight.w800,
          fontSize: 17,
        ),
      ),
      const SizedBox(height: 10),
      ...children,
    ],
  ),
);

Widget infoRow(IconData icon, String text) => Padding(
  padding: const EdgeInsets.only(top: 8),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: rose),
      const SizedBox(width: 8),
      Expanded(
        child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
      ),
    ],
  ),
);

Widget statusPill(String text) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  decoration: BoxDecoration(
    color: rose.withAlpha(25),
    borderRadius: BorderRadius.circular(20),
  ),
  child: Text(
    text,
    style: const TextStyle(
      color: rose,
      fontSize: 12,
      fontWeight: FontWeight.bold,
    ),
  ),
);

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class Participant {
  Participant({
    String? id,
    required this.name,
    required this.email,
    this.availableDates = const [],
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();
  final String id;
  final String name;
  final String email;
  final List<DateTime> availableDates;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'availableDates': availableDates
        .map((date) => date.toIso8601String())
        .toList(),
  };
  factory Participant.fromJson(Map<String, dynamic> json) => Participant(
    id: json['id'] as String?,
    name: json['name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    availableDates: ((json['availableDates'] as List?) ?? [])
        .map((date) => DateTime.parse(date as String))
        .toList(),
  );
}

class LocationSuggestion {
  const LocationSuggestion({
    required this.name,
    required this.latitude,
    required this.longitude,
  });
  final String name;
  final double latitude;
  final double longitude;
}

class GalaLocation {
  const GalaLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
  });
  final String name;
  final double latitude;
  final double longitude;

  Map<String, dynamic> toJson() => {
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
  };

  factory GalaLocation.fromJson(Map<String, dynamic> json) => GalaLocation(
    name: json['name'] as String? ?? '',
    latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
    longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
  );
}

/// Daily forecast for one date, from Open-Meteo (no API key needed).
class WeatherInfo {
  const WeatherInfo({
    required this.code,
    required this.max,
    required this.min,
    this.rainChance,
  });
  final int code;
  final double max;
  final double min;
  final int? rainChance;

  String get label => switch (code) {
    0 => 'Clear sky',
    1 => 'Mainly clear',
    2 => 'Partly cloudy',
    3 => 'Overcast',
    45 || 48 => 'Fog',
    51 || 53 || 55 || 56 || 57 => 'Drizzle',
    61 || 63 || 65 || 66 || 67 => 'Rain',
    71 || 73 || 75 || 77 => 'Snow',
    80 || 81 || 82 => 'Rain showers',
    85 || 86 => 'Snow showers',
    95 || 96 || 99 => 'Thunderstorm',
    _ => 'Unknown',
  };

  IconData get icon => weatherIconFor(code);

  String get range => '${min.round()}° / ${max.round()}°C';

  String get summary {
    final rain = rainChance;
    final rainText = rain == null ? '' : ' · $rain% rain';
    return '$label · $range$rainText';
  }
}

class Gala {
  Gala({
    String? id,
    required this.name,
    required this.date,
    required this.location,
    this.locations = const [],
    this.latitude = 0,
    this.longitude = 0,
    this.status = 'Planned',
    this.plan = '',
    this.tags = const [],
    this.weather = '',
    this.weatherCode = -1,
    this.signupLink = '',
    this.thumbnail = '',
    this.participantIds = const [],
    this.rsvps = const {},
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();
  final String id;
  final String name;
  final DateTime date;
  final String location;
  final List<GalaLocation> locations;
  final double latitude;
  final double longitude;
  final String status;
  final String plan;

  /// Type of outing, e.g. Dinner, Beach, Karaoke.
  final List<String> tags;
  final String weather;
  final int weatherCode;

  /// Optional link (Google Form etc.) added to the invite message.
  final String signupLink;

  /// Base64 PNG of the plan image, captured when the gala is saved.
  final String thumbnail;
  final List<String> participantIds;

  /// participant id -> 'going' | 'maybe' | 'declined'. Missing = waiting.
  final Map<String, String> rsvps;

  late final Uint8List? thumbnailBytes = () {
    if (thumbnail.isEmpty) return null;
    try {
      return base64Decode(thumbnail);
    } on FormatException {
      return null;
    }
  }();

  /// Locations, including older galas that only stored one coordinate.
  List<GalaLocation> get places {
    if (locations.isNotEmpty) return locations;
    if (latitude != 0 && longitude != 0) {
      return [
        GalaLocation(
          name: location.isEmpty ? 'Pinned location' : location,
          latitude: latitude,
          longitude: longitude,
        ),
      ];
    }
    return const [];
  }

  int get goingCount =>
      participantIds.where((id) => rsvps[id] == 'going').length;

  Gala copyWith({
    String? weather,
    int? weatherCode,
    Map<String, String>? rsvps,
  }) => Gala(
    id: id,
    name: name,
    date: date,
    location: location,
    locations: locations,
    latitude: latitude,
    longitude: longitude,
    status: status,
    plan: plan,
    tags: tags,
    weather: weather ?? this.weather,
    weatherCode: weatherCode ?? this.weatherCode,
    signupLink: signupLink,
    thumbnail: thumbnail,
    participantIds: participantIds,
    rsvps: rsvps ?? this.rsvps,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'scheduledDate': date.toIso8601String(),
    'location': location,
    'locations': locations.map((item) => item.toJson()).toList(),
    'latitude': latitude,
    'longitude': longitude,
    'status': status,
    'plan': plan,
    'tags': tags,
    'weather': weather,
    'weatherCode': weatherCode,
    'signupLink': signupLink,
    'thumbnail': thumbnail,
    'participantIds': participantIds,
    'rsvps': rsvps,
  };

  factory Gala.fromJson(Map<String, dynamic> json) {
    // Older versions stored outing types as "genres". Fold them into tags.
    final tags = <String>[...((json['tags'] as List?) ?? []).cast<String>()];
    for (final genre in ((json['genres'] as List?) ?? []).cast<String>()) {
      if (!tags.any((tag) => tag.toLowerCase() == genre.toLowerCase())) {
        tags.add(genre);
      }
    }
    final rawRsvps = (json['rsvps'] as Map?) ?? const {};
    return Gala(
      id: json['id'] as String?,
      name: json['name'] as String? ?? '',
      date:
      DateTime.tryParse(json['scheduledDate'] as String? ?? '') ??
          DateTime.now(),
      location: json['location'] as String? ?? '',
      locations: ((json['locations'] as List?) ?? [])
          .map(
            (item) =>
            GalaLocation.fromJson((item as Map).cast<String, dynamic>()),
      )
          .toList(),
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'Planned',
      plan: json['plan'] as String? ?? '',
      tags: tags,
      weather: json['weather'] as String? ?? '',
      weatherCode: (json['weatherCode'] as num?)?.toInt() ?? -1,
      signupLink: json['signupLink'] as String? ?? '',
      thumbnail: json['thumbnail'] as String? ?? '',
      participantIds: ((json['participantIds'] as List?) ?? [])
          .cast<String>(),
      rsvps: rawRsvps.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
      ),
    );
  }
}

class LocalStore {
  Future<List<Gala>> galas() async {
    final prefs = await SharedPreferences.getInstance();
    return (jsonDecode(prefs.getString('galas') ?? '[]') as List)
        .map((item) => Gala.fromJson((item as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<Participant>> participants() async {
    final prefs = await SharedPreferences.getInstance();
    return (jsonDecode(prefs.getString('participants') ?? '[]') as List)
        .map(
          (item) => Participant.fromJson((item as Map).cast<String, dynamic>()),
    )
        .toList();
  }

  Future<void> saveGalas(List<Gala> items) async =>
      (await SharedPreferences.getInstance()).setString(
        'galas',
        jsonEncode(items.map((item) => item.toJson()).toList()),
      );
  Future<void> saveParticipants(List<Participant> items) async =>
      (await SharedPreferences.getInstance()).setString(
        'participants',
        jsonEncode(items.map((item) => item.toJson()).toList()),
      );
}

// ---------------------------------------------------------------------------
// API
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Plan image
// ---------------------------------------------------------------------------

/// The shareable plan image. Always 3:4. The content is drawn on a fixed
/// 360x480 canvas and scaled, so exports look identical on every device.
class PlanCard extends StatelessWidget {
  const PlanCard({
    super.key,
    required this.name,
    required this.date,
    required this.locations,
    required this.tags,
    required this.plan,
    this.weatherText = '',
    this.weatherCode = -1,
  });
  final String name;
  final DateTime date;
  final List<GalaLocation> locations;
  final List<String> tags;
  final String plan;
  final String weatherText;
  final int weatherCode;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 3 / 4,
    child: FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(width: 360, height: 480, child: canvas()),
    ),
  );

  Widget line(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(top: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white70, size: 17),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ),
      ],
    ),
  );

  Widget caption(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white54,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.6,
      ),
    ),
  );

  Widget pill(String text) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white.withAlpha(45),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );

  Widget canvas() {
    final stops = locations.take(4).toList();
    final extraStops = locations.length - stops.length;
    final shownTags = tags.take(6).toList();
    final extraTags = tags.length - shownTags.length;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [plum, rose],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.explore_rounded, color: Colors.white, size: 24),
                SizedBox(width: 8),
                Text(
                  'OUTLY',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              name.trim().isEmpty ? 'Untitled gala' : name.trim(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                height: 1.05,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            line(Icons.calendar_month_outlined, longDate(date)),
            if (weatherText.isNotEmpty)
              line(weatherIconFor(weatherCode), weatherText),
            const SizedBox(height: 18),
            // If there's too much content, shrink it instead of overflowing.
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 308,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (stops.isNotEmpty) ...[
                        caption('STOPS'),
                        for (var i = 0; i < stops.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withAlpha(45),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '${i + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    shortName(stops[i].name),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (extraStops > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              '+$extraStops more',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        const SizedBox(height: 6),
                      ],
                      if (shownTags.isNotEmpty) ...[
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            ...shownTags.map(pill),
                            if (extraTags > 0) pill('+$extraTags'),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (plan.trim().isNotEmpty) ...[
                        caption('THE PLAN'),
                        Text(
                          plan.trim(),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Home
// ---------------------------------------------------------------------------

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final store = LocalStore();
  final api = ApiService();
  List<Gala> galas = [];
  List<Participant> people = [];
  int tab = 0;
  bool loading = true;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    galas = await store.galas();
    people = await store.participants();
    if (mounted) setState(() => loading = false);
  }

  /// Returns false if the gala couldn't be saved (e.g. date clash).
  Future<bool> saveGala(Gala gala) async {
    if (galas.any(
          (item) => item.id != gala.id && sameDay(item.date, gala.date),
    )) {
      message('Another gala is already scheduled on ${dateText(gala.date)}.');
      return false;
    }
    final index = galas.indexWhere((item) => item.id == gala.id);
    if (index == -1) {
      galas = [...galas, gala];
    } else {
      galas = [...galas]..[index] = gala;
    }
    await store.saveGalas(galas);
    if (mounted) setState(() {});
    return true;
  }

  Future<void> edit([Gala? gala]) async {
    final result = await Navigator.push<Gala>(
      context,
      MaterialPageRoute(
        builder: (_) => GalaEditor(gala: gala, people: people, api: api),
      ),
    );
    if (result != null) await saveGala(result);
  }

  Future<void> openDetail(Gala gala) => Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => GalaDetailPage(
        gala: gala,
        people: people,
        api: api,
        onSave: saveGala,
      ),
    ),
  );

  void message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Outly',
          style: TextStyle(fontWeight: FontWeight.w800, color: plum),
        ),
        backgroundColor: cream,
        actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh))],
      ),
      body: IndexedStack(
        index: tab,
        children: [
          dashboard(),
          ParticipantsPage(people: people, store: store, onChanged: load),
        ],
      ),
      floatingActionButton: tab == 0
          ? FloatingActionButton.extended(
        onPressed: edit,
        backgroundColor: rose,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New gala'),
      )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (index) => setState(() => tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event),
            label: 'Galas',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Participants',
          ),
        ],
      ),
    );
  }

  Widget dashboard() {
    final items = [...galas]..sort((a, b) => a.date.compareTo(b.date));
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        children: [
          Text(
            'Plan something memorable.',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800, color: plum),
          ),
          const SizedBox(height: 4),
          Text(
            '${galas.length} gala${galas.length == 1 ? '' : 's'} planned',
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 22),
          if (items.isEmpty) emptyState() else ...items.map(galaCard),
        ],
      ),
    );
  }

  Widget emptyState() => const Card(
    child: Padding(
      padding: EdgeInsets.all(28),
      child: Column(
        children: [
          Icon(Icons.celebration_outlined, size: 52, color: rose),
          SizedBox(height: 12),
          Text(
            'Your next gala starts here',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          SizedBox(height: 6),
          Text(
            'Add a date, location, plan, and people to get organized.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );

  Widget thumbnail(Gala gala) {
    final bytes = gala.thumbnailBytes;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 84,
        height: 112,
        child: bytes == null
            ? Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [plum, rose],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Icon(
            Icons.celebration_outlined,
            color: Colors.white70,
            size: 30,
          ),
        )
            : Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),
      ),
    );
  }

  Widget galaCard(Gala gala) {
    final places = gala.places;
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => openDetail(gala),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              thumbnail(gala),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            gala.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: plum,
                            ),
                          ),
                        ),
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          onSelected: (value) async {
                            if (value == 'edit') {
                              await edit(gala);
                            } else if (value == 'delete') {
                              galas.removeWhere((item) => item.id == gala.id);
                              await store.saveGalas(galas);
                              setState(() {});
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete gala'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: statusPill(gala.status),
                    ),
                    infoRow(Icons.calendar_month_outlined, dateText(gala.date)),
                    infoRow(
                      Icons.location_on_outlined,
                      places.isEmpty
                          ? 'Location not set'
                          : places
                          .map((item) => shortName(item.name))
                          .join(' · '),
                    ),
                    if (gala.weather.isNotEmpty)
                      infoRow(
                        weatherIconFor(gala.weatherCode),
                        gala.weather,
                      ),
                    if (gala.tags.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          gala.tags.join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: rose,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      '${gala.goingCount} going · ${gala.participantIds.length} invited',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Gala details (read view, RSVPs, invite)
// ---------------------------------------------------------------------------

({String label, Color color}) rsvpStyle(String? status) => switch (status) {
  'going' => (label: 'Going', color: Colors.green.shade600),
  'maybe' => (label: 'Maybe', color: Colors.orange.shade700),
  'declined' => (label: "Can't go", color: Colors.red.shade400),
  _ => (label: 'Waiting', color: Colors.black45),
};

class GalaDetailPage extends StatefulWidget {
  const GalaDetailPage({
    super.key,
    required this.gala,
    required this.people,
    required this.api,
    required this.onSave,
  });
  final Gala gala;
  final List<Participant> people;
  final ApiService api;
  final Future<bool> Function(Gala) onSave;
  @override
  State<GalaDetailPage> createState() => _GalaDetailPageState();
}

class _GalaDetailPageState extends State<GalaDetailPage> {
  late Gala gala;
  final planKey = GlobalKey();
  final mapController = MapController();
  WeatherInfo? liveWeather;

  @override
  void initState() {
    super.initState();
    gala = widget.gala;
    refreshWeather();
  }

  void message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  /// Re-checks the forecast so the page never shows stale weather.
  Future<void> refreshWeather() async {
    final places = gala.places;
    if (places.isEmpty) return;
    try {
      final result = await widget.api.fetchWeather(
        places.first.latitude,
        places.first.longitude,
        gala.date,
      );
      if (!mounted || result == null) return;
      setState(() => liveWeather = result);
      if (result.summary != gala.weather || result.code != gala.weatherCode) {
        final updated = gala.copyWith(
          weather: result.summary,
          weatherCode: result.code,
        );
        setState(() => gala = updated);
        await widget.onSave(updated);
      }
    } catch (_) {
      // Keep showing the saved weather if the lookup fails.
    }
  }

  Future<void> edit() async {
    final result = await Navigator.push<Gala>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            GalaEditor(gala: gala, people: widget.people, api: widget.api),
      ),
    );
    if (result == null) return;
    if (await widget.onSave(result) && mounted) {
      setState(() {
        gala = result;
        liveWeather = null;
      });
      refreshWeather();
    }
  }

  Future<void> setRsvp(String personId, String? status) async {
    final next = {...gala.rsvps};
    if (status == null) {
      next.remove(personId);
    } else {
      next[personId] = status;
    }
    final updated = gala.copyWith(rsvps: next);
    setState(() => gala = updated);
    await widget.onSave(updated);
  }

  String inviteText() {
    final buffer = StringBuffer()
      ..writeln("You're invited: ${gala.name}")
      ..writeln()
      ..writeln('📅 ${longDate(gala.date)}');
    for (final place in gala.places) {
      buffer.writeln('📍 ${shortName(place.name)}');
    }
    final weather = liveWeather?.summary ?? gala.weather;
    if (weather.isNotEmpty) buffer.writeln('🌤 $weather');
    if (gala.tags.isNotEmpty) buffer.writeln('🏷 ${gala.tags.join(', ')}');
    if (gala.plan.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln(gala.plan.trim());
    }
    buffer.writeln();
    if (gala.signupLink.isNotEmpty) {
      buffer.writeln('Sign up here: ${gala.signupLink}');
    }
    buffer.write('Reply "I\'m in" in this chat to join!');
    return buffer.toString();
  }

  Future<void> shareInvite() async {
    try {
      final bytes = await capturePng(planKey, width: 1080);
      await SharePlus.instance.share(
        ShareParams(
          text: inviteText(),
          files: [
            if (bytes != null)
              XFile.fromData(
                bytes,
                mimeType: 'image/png',
                name: planFileName(gala.name),
              ),
          ],
        ),
      );
    } on Exception {
      message('Unable to share the invite.');
    }
  }

  Future<void> shareImage() async {
    try {
      final bytes = await capturePng(planKey, width: 1080);
      if (bytes == null) {
        message('Unable to create the plan image.');
        return;
      }
      await SharePlus.instance.share(
        ShareParams(
          text: 'Outly plan: ${gala.name}',
          files: [
            XFile.fromData(
              bytes,
              mimeType: 'image/png',
              name: planFileName(gala.name),
            ),
          ],
        ),
      );
    } on Exception {
      message('Unable to export the plan image.');
    }
  }

  Future<void> downloadImage() async {
    try {
      final bytes = await capturePng(planKey, width: 1080);
      if (bytes == null) {
        message('Unable to create the plan image.');
        return;
      }
      await Gal.putImageBytes(bytes, album: 'Outly');
      message('Image saved to your gallery.');
    } on Exception {
      message('Unable to save the plan image. Check gallery permissions.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final invited = widget.people
        .where((person) => gala.participantIds.contains(person.id))
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(gala.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Edit gala',
            onPressed: edit,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      // A plain scroll view keeps the plan image built so it can be shared.
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            headerCard(),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: shareInvite,
              style: FilledButton.styleFrom(
                backgroundColor: rose,
                minimumSize: const Size.fromHeight(50),
              ),
              icon: const Icon(Icons.send_rounded),
              label: const Text('Send invite to your group chat'),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Shares the plan image and details. When people reply, mark them below.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ),
            section('Locations', locationWidgets()),
            if (gala.plan.trim().isNotEmpty)
              section('Plan', [
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      gala.plan.trim(),
                      style: const TextStyle(height: 1.4),
                    ),
                  ),
                ),
              ]),
            section('Who\'s coming', participantWidgets(invited)),
            section('Plan image', [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: RepaintBoundary(
                  key: planKey,
                  child: PlanCard(
                    name: gala.name,
                    date: gala.date,
                    locations: gala.places,
                    tags: gala.tags,
                    plan: gala.plan,
                    weatherText: liveWeather?.summary ?? gala.weather,
                    weatherCode: liveWeather?.code ?? gala.weatherCode,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: shareImage,
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Share image'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: downloadImage,
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Download'),
                    ),
                  ),
                ],
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget headerCard() {
    final weatherText = liveWeather?.summary ?? gala.weather;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    gala.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      color: plum,
                    ),
                  ),
                ),
                statusPill(gala.status),
              ],
            ),
            const SizedBox(height: 4),
            infoRow(Icons.calendar_month_outlined, longDate(gala.date)),
            if (weatherText.isNotEmpty)
              infoRow(
                liveWeather?.icon ?? weatherIconFor(gala.weatherCode),
                weatherText,
              ),
            if (gala.signupLink.isNotEmpty)
              infoRow(Icons.link, gala.signupLink),
            if (gala.tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: gala.tags
                      .map(
                        (tag) => Chip(
                      label: Text(tag),
                      backgroundColor: rose.withAlpha(25),
                      side: BorderSide.none,
                      labelStyle: const TextStyle(
                        color: rose,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> locationWidgets() {
    final places = gala.places;
    if (places.isEmpty) {
      return [
        const Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('No location set yet. Tap the pencil to add one.'),
          ),
        ),
      ];
    }
    final points = places
        .map((place) => LatLng(place.latitude, place.longitude))
        .toList();
    return [
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 220,
          child: FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: points.first,
              initialZoom: 15,
              initialCameraFit: points.length > 1
                  ? CameraFit.coordinates(
                coordinates: points,
                padding: const EdgeInsets.all(48),
                maxZoom: 16,
              )
                  : null,
              // Static map so it doesn't fight with page scrolling.
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.none,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.outly',
              ),
              MarkerLayer(
                markers: [
                  for (var i = 0; i < points.length; i++)
                    Marker(
                      point: points[i],
                      width: 34,
                      height: 34,
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: rose,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [
                            BoxShadow(blurRadius: 4, color: Colors.black26),
                          ],
                        ),
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 10),
      Card(
        margin: EdgeInsets.zero,
        child: Column(
          children: [
            for (var i = 0; i < places.length; i++)
              ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: rose,
                  foregroundColor: Colors.white,
                  child: Text('${i + 1}'),
                ),
                title: Text(
                  shortName(places[i].name),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: shortName(places[i].name) == places[i].name
                    ? null
                    : Text(
                  places[i].name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.my_location, size: 18, color: rose),
                onTap: () => mapController.move(points[i], 16),
              ),
          ],
        ),
      ),
    ];
  }

  Widget rsvpChip(String? status) {
    final style = rsvpStyle(status);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 5, 6, 5),
      decoration: BoxDecoration(
        color: style.color.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            style.label,
            style: TextStyle(
              color: style.color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          Icon(Icons.arrow_drop_down, size: 18, color: style.color),
        ],
      ),
    );
  }

  List<Widget> participantWidgets(List<Participant> invited) {
    if (invited.isEmpty) {
      return [
        const Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'No one invited yet. Tap the pencil and pick people from your Participants list.',
            ),
          ),
        ),
      ];
    }
    int count(String status) =>
        invited.where((person) => gala.rsvps[person.id] == status).length;
    final going = count('going');
    final maybe = count('maybe');
    final declined = count('declined');
    final waiting = invited.length - going - maybe - declined;
    return [
      Text(
        "$going going · $maybe maybe · $declined can't go · $waiting waiting",
        style: const TextStyle(color: Colors.black54),
      ),
      const SizedBox(height: 8),
      Card(
        margin: EdgeInsets.zero,
        child: Column(
          children: invited.map((person) {
            final status = gala.rsvps[person.id];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: rose.withAlpha(35),
                child: Text(
                  person.name.isEmpty ? '?' : person.name[0].toUpperCase(),
                  style: const TextStyle(
                    color: rose,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(person.name.isEmpty ? 'Unnamed' : person.name),
              subtitle: Text(person.email),
              trailing: PopupMenuButton<String>(
                onSelected: (value) =>
                    setRsvp(person.id, value == 'waiting' ? null : value),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'going', child: Text('Going')),
                  PopupMenuItem(value: 'maybe', child: Text('Maybe')),
                  PopupMenuItem(value: 'declined', child: Text("Can't go")),
                  PopupMenuItem(value: 'waiting', child: Text('Waiting')),
                ],
                child: rsvpChip(status),
              ),
            );
          }).toList(),
        ),
      ),
    ];
  }
}

// ---------------------------------------------------------------------------
// Editor
// ---------------------------------------------------------------------------

class GalaEditor extends StatefulWidget {
  const GalaEditor({
    super.key,
    this.gala,
    required this.people,
    required this.api,
  });
  final Gala? gala;
  final List<Participant> people;
  final ApiService api;
  @override
  State<GalaEditor> createState() => _GalaEditorState();
}

class _GalaEditorState extends State<GalaEditor> {
  late final TextEditingController name, location, plan, tagInput, signup;
  late DateTime date;
  String status = 'Planned';
  double lat = 0, lon = 0;
  List<LocationSuggestion> suggestions = [];
  final locations = <GalaLocation>[];
  int activeLocation = 0;
  final tags = <String>[];
  Timer? suggestionTimer;
  final planBoundaryKey = GlobalKey();
  final selected = <String>{};
  bool busy = false;
  bool saving = false;

  // Weather for the chosen date at the active location.
  WeatherInfo? weather;
  String weatherText = '';
  int weatherCode = -1;
  String? weatherNote;
  bool weatherBusy = false;
  int weatherRequest = 0;

  String thumbnail = '';

  @override
  void initState() {
    super.initState();
    final gala = widget.gala;
    name = TextEditingController(text: gala?.name);
    location = TextEditingController(text: gala?.location);
    plan = TextEditingController(text: gala?.plan);
    signup = TextEditingController(text: gala?.signupLink);
    tagInput = TextEditingController();
    date = gala?.date ?? DateTime.now().add(const Duration(days: 1));
    status = gala?.status ?? 'Planned';
    lat = gala?.latitude ?? 0;
    lon = gala?.longitude ?? 0;
    weatherText = gala?.weather ?? '';
    weatherCode = gala?.weatherCode ?? -1;
    thumbnail = gala?.thumbnail ?? '';
    locations.addAll(gala?.locations ?? const []);
    if (locations.isEmpty && lat != 0 && lon != 0) {
      locations.add(
        GalaLocation(name: gala?.location ?? '', latitude: lat, longitude: lon),
      );
    }
    if (locations.isNotEmpty) {
      lat = locations.first.latitude;
      lon = locations.first.longitude;
      if (location.text.trim().isEmpty) {
        location.text = locations.first.name;
      }
    }
    tags.addAll(gala?.tags ?? const []);
    selected.addAll(gala?.participantIds ?? []);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) loadWeather();
    });
  }

  @override
  void dispose() {
    name.dispose();
    location.dispose();
    plan.dispose();
    tagInput.dispose();
    signup.dispose();
    suggestionTimer?.cancel();
    super.dispose();
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      initialDate: date,
    );
    if (picked != null) {
      setState(() {
        date = picked;
      });
      loadWeather();
    }
  }

  Future<void> loadWeather() async {
    final request = ++weatherRequest;
    if (lat == 0 || lon == 0) {
      setState(() {
        weather = null;
        weatherText = '';
        weatherCode = -1;
        weatherNote = 'Add a location to see the forecast.';
        weatherBusy = false;
      });
      return;
    }
    setState(() {
      weatherBusy = true;
      weatherNote = null;
    });
    try {
      final result = await widget.api.fetchWeather(lat, lon, date);
      if (!mounted || request != weatherRequest) return;
      setState(() {
        weather = result;
        weatherText = result?.summary ?? '';
        weatherCode = result?.code ?? -1;
        weatherNote = result == null
            ? 'Forecasts reach 16 days ahead. Check back closer to the date.'
            : null;
        weatherBusy = false;
      });
    } catch (_) {
      if (!mounted || request != weatherRequest) return;
      setState(() {
        weatherBusy = false;
        weatherNote = 'Weather unavailable right now. Tap refresh to retry.';
      });
    }
  }

  Future<void> geocode() async {
    final query = location.text.trim();
    if (query.isEmpty) return;
    setState(() => busy = true);
    try {
      final results = await widget.api.searchLocations(query);
      if (!mounted) return;
      if (results.isNotEmpty) {
        addLocation(
          results.first.name,
          results.first.latitude,
          results.first.longitude,
        );
      }
      setState(() {
        suggestions = results;
        busy = false;
      });
      if (results.isEmpty) message('Location not found.');
    } catch (e) {
      if (!mounted) return;
      setState(() => busy = false);
      message('Location search failed: $e');
    }
  }

  void addLocation(String name, double latitude, double longitude) {
    if (latitude == 0 ||
        longitude == 0 ||
        locations.any(
              (item) =>
          item.name == name &&
              item.latitude == latitude &&
              item.longitude == longitude,
        )) {
      return;
    }
    setState(() {
      locations.add(
        GalaLocation(name: name, latitude: latitude, longitude: longitude),
      );
      activeLocation = locations.length - 1;
      location.clear();
      lat = latitude;
      lon = longitude;
    });
    loadWeather();
  }

  void selectLocation(int index) {
    final selectedLocation = locations[index];
    setState(() {
      activeLocation = index;
      location.text = selectedLocation.name;
      lat = selectedLocation.latitude;
      lon = selectedLocation.longitude;
    });
    loadWeather();
  }

  void removeLocation(int index) {
    setState(() {
      locations.removeAt(index);
      if (locations.isEmpty) {
        activeLocation = 0;
        lat = 0;
        lon = 0;
      } else {
        activeLocation = activeLocation >= locations.length
            ? locations.length - 1
            : activeLocation;
        final selectedLocation = locations[activeLocation];
        location.text = selectedLocation.name;
        lat = selectedLocation.latitude;
        lon = selectedLocation.longitude;
      }
    });
    loadWeather();
  }

  Future<void> renameLocation(int index) async {
    final old = locations[index];
    final controller = TextEditingController(text: old.name);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename location'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty || !mounted) return;
    setState(() {
      locations[index] = GalaLocation(
        name: result,
        latitude: old.latitude,
        longitude: old.longitude,
      );
      if (location.text == old.name) location.text = result;
    });
  }

  bool hasTag(String tag) =>
      tags.any((item) => item.toLowerCase() == tag.toLowerCase());

  void toggleTag(String tag) {
    setState(() {
      if (hasTag(tag)) {
        tags.removeWhere((item) => item.toLowerCase() == tag.toLowerCase());
      } else if (tags.length < 12) {
        tags.add(tag);
      }
    });
  }

  void addTag() {
    setState(() {
      for (final raw in tagInput.text.split(',')) {
        var tag = raw.trim().replaceAll(RegExp(r'^#+'), '').trim();
        if (tag.isEmpty) continue;
        if (tag.length > 24) tag = tag.substring(0, 24);
        if (tags.length >= 12) break;
        if (hasTag(tag)) continue;
        tags.add(tag);
      }
      tagInput.clear();
    });
  }

  Future<void> exportPlan() async {
    try {
      final bytes = await capturePng(planBoundaryKey, width: 1080);
      if (bytes == null) {
        message('Unable to create the plan image.');
        return;
      }
      await SharePlus.instance.share(
        ShareParams(
          text: 'Outly plan: ${name.text.trim()}',
          files: [
            XFile.fromData(
              bytes,
              mimeType: 'image/png',
              name: planFileName(name.text),
            ),
          ],
        ),
      );
    } on Exception {
      message('Unable to export the plan image.');
    }
  }

  Future<void> downloadPlan() async {
    try {
      final bytes = await capturePng(planBoundaryKey, width: 1080);
      if (bytes == null) {
        message('Unable to create the plan image.');
        return;
      }
      await Gal.putImageBytes(bytes, album: 'Outly');
      message('Image saved to your gallery.');
    } on Exception {
      message('Unable to save the plan image. Check gallery permissions.');
    }
  }

  Future<void> openPinMap() async {
    final picked = await Navigator.push<GalaLocation>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            PinPickerPage(existing: List.of(locations), api: widget.api),
      ),
    );
    if (picked != null) {
      addLocation(picked.name, picked.latitude, picked.longitude);
    }
  }

  Future<void> save() async {
    if (name.text.trim().isEmpty) {
      message('Give your gala a name first.');
      return;
    }
    setState(() => saving = true);
    var thumb = thumbnail;
    try {
      final bytes = await capturePng(planBoundaryKey, width: 320);
      if (bytes != null) thumb = base64Encode(bytes);
    } on Exception {
      // Keep the previous thumbnail if capturing fails.
    }
    if (!mounted) return;
    final oldRsvps = widget.gala?.rsvps ?? const <String, String>{};
    Navigator.pop(
      context,
      Gala(
        id: widget.gala?.id,
        name: name.text.trim(),
        date: date,
        location: location.text.trim(),
        locations: locations,
        latitude: lat,
        longitude: lon,
        status: status,
        plan: plan.text.trim(),
        tags: tags.toList(),
        weather: weatherText,
        weatherCode: weatherCode,
        signupLink: signup.text.trim(),
        thumbnail: thumb,
        participantIds: selected.toList(),
        // Keep RSVPs, dropping anyone who is no longer invited.
        rsvps: {
          for (final entry in oldRsvps.entries)
            if (selected.contains(entry.key)) entry.key: entry.value,
        },
      ),
    );
  }

  void message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.gala == null ? 'New gala' : 'Edit gala'),
      actions: [
        TextButton(
          onPressed: saving ? null : save,
          child: saving
              ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Text('Save'),
        ),
      ],
    ),
    // A plain scroll view (not a lazy ListView) keeps the plan card built
    // at all times, so it can always be captured for the thumbnail.
    body: SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          section('Gala details', [
            TextField(
              controller: name,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Gala name',
                prefixIcon: Icon(Icons.celebration_outlined),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: pickDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date',
                        prefixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                      child: Text(dateText(date)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: ['Planned', 'Confirmed', 'Completed', 'Cancelled']
                        .map(
                          (item) =>
                          DropdownMenuItem(value: item, child: Text(item)),
                    )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => status = value ?? status),
                  ),
                ),
              ],
            ),
          ]),
          section('Type of outing', [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ...suggestedTags.map(
                      (tag) => FilterChip(
                    label: Text(tag),
                    selected: hasTag(tag),
                    onSelected: (_) => toggleTag(tag),
                  ),
                ),
                ...tags
                    .where(
                      (tag) => !suggestedTags.any(
                        (item) => item.toLowerCase() == tag.toLowerCase(),
                  ),
                )
                    .map(
                      (tag) => InputChip(
                    label: Text(tag),
                    selected: true,
                    showCheckmark: false,
                    onDeleted: () => setState(() => tags.remove(tag)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: tagInput,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => addTag(),
                    decoration: const InputDecoration(
                      labelText: 'Add your own',
                      hintText: 'e.g. Bar crawl, Picnic',
                      prefixIcon: Icon(Icons.sell_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: addTag,
                  style: IconButton.styleFrom(backgroundColor: rose),
                  icon: const Icon(Icons.add),
                  tooltip: 'Add tag',
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Tags show on the plan image and in the invite. Separate several with commas.',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ]),
          section('Weather', [weatherCard()]),
          section('Locations', [
            TextField(
              controller: location,
              decoration: InputDecoration(
                labelText: 'Meeting location',
                prefixIcon: const Icon(Icons.location_on_outlined),
                suffixIcon: IconButton(
                  onPressed: busy ? null : geocode,
                  icon: const Icon(Icons.search),
                ),
              ),
              onChanged: (value) {
                suggestionTimer?.cancel();
                if (value.trim().length < 3) {
                  setState(() => suggestions = []);
                  return;
                }
                suggestionTimer = Timer(
                  const Duration(milliseconds: 800),
                      () async {
                    try {
                      final results = await widget.api.searchLocations(
                        value.trim(),
                      );
                      if (mounted && location.text.trim() == value.trim()) {
                        setState(() => suggestions = results);
                      }
                    } on Exception {
                      if (mounted) {
                        setState(() => suggestions = []);
                      }
                    }
                  },
                );
              },
            ),
            if (suggestions.isNotEmpty)
              Card(
                margin: const EdgeInsets.only(top: 6),
                child: Column(
                  children: suggestions
                      .map(
                        (suggestion) => ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.location_on_outlined,
                        color: rose,
                      ),
                      title: Text(
                        suggestion.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        addLocation(
                          suggestion.name,
                          suggestion.latitude,
                          suggestion.longitude,
                        );
                        setState(() => suggestions = []);
                      },
                    ),
                  )
                      .toList(),
                ),
              ),
            const SizedBox(height: 10),
            if (locations.isNotEmpty)
              Card(
                elevation: 0,
                margin: EdgeInsets.zero,
                color: rose.withAlpha(18),
                child: Column(
                  children: locations.asMap().entries.map((entry) {
                    final index = entry.key;
                    final place = entry.value;
                    return ListTile(
                      dense: true,
                      selected: activeLocation == index,
                      selectedTileColor: rose.withAlpha(18),
                      leading: CircleAvatar(
                        backgroundColor: rose,
                        foregroundColor: Colors.white,
                        child: Text('${index + 1}'),
                      ),
                      title: Text(
                        place.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        activeLocation == index
                            ? 'Selected location'
                            : 'Tap to select',
                      ),
                      onTap: () => selectLocation(index),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Rename location',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => renameLocation(index),
                          ),
                          IconButton(
                            tooltip: 'Remove location',
                            icon: const Icon(Icons.close),
                            onPressed: () => removeLocation(index),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: openPinMap,
                icon: const Icon(Icons.pin_drop_outlined),
                label: const Text('Pin a location on the map'),
              ),
            ),
            if (lat != 0 && lon != 0)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Location found with OpenStreetMap',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ),
            if (busy) const LinearProgressIndicator(),
          ]),
          section('Plan', [
            TextField(
              controller: plan,
              minLines: 3,
              maxLines: 5,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'What is the plan?',
                alignLabelWithHint: true,
              ),
            ),
          ]),
          section('Sign-up link (optional)', [
            TextField(
              controller: signup,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Link people can sign up with',
                hintText: 'Google Form, Doodle, etc.',
                prefixIcon: Icon(Icons.link),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Added to the invite message when you send it to your group chat.',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ]),
          section('Plan image', [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: RepaintBoundary(
                key: planBoundaryKey,
                child: PlanCard(
                  name: name.text,
                  date: date,
                  locations: locations,
                  tags: tags,
                  plan: plan.text,
                  weatherText: weatherText,
                  weatherCode: weatherCode,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: exportPlan,
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('Share image'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: downloadPlan,
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Download'),
                  ),
                ),
              ],
            ),
          ]),
          section('Invite people', [
            if (widget.people.isEmpty)
              const Text(
                'Add participants from the Participants tab.',
                style: TextStyle(color: Colors.black54),
              ),
            ...widget.people.map(
                  (person) => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: selected.contains(person.id),
                title: Text(person.name.isEmpty ? 'Unnamed' : person.name),
                subtitle: Text(person.email),
                activeColor: rose,
                onChanged: (value) => setState(
                      () => value == true
                      ? selected.add(person.id)
                      : selected.remove(person.id),
                ),
              ),
            ),
          ]),
        ],
      ),
    ),
  );

  Widget weatherCard() {
    final forecast = weather;
    final place = activeLocation < locations.length
        ? locations[activeLocation].name
        : '';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 6, 12),
        child: Row(
          children: [
            Icon(forecast?.icon ?? Icons.cloud_outlined, color: rose, size: 32),
            const SizedBox(width: 14),
            Expanded(
              child: weatherBusy
                  ? const Text('Checking the forecast…')
                  : forecast != null
                  ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    forecast.label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: plum,
                    ),
                  ),
                  Text(
                    forecast.rainChance == null
                        ? forecast.range
                        : '${forecast.range} · ${forecast.rainChance}% rain',
                  ),
                  if (place.isNotEmpty)
                    Text(
                      'For ${shortName(place)} on ${dateText(date)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                ],
              )
                  : Text(
                weatherNote ??
                    (weatherText.isEmpty
                        ? 'No forecast yet.'
                        : weatherText),
                style: const TextStyle(color: Colors.black54),
              ),
            ),
            IconButton(
              tooltip: 'Refresh weather',
              onPressed: weatherBusy ? null : loadWeather,
              icon: const Icon(Icons.refresh, color: rose),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pin picker
// ---------------------------------------------------------------------------

/// Full-screen map for dropping and naming a pin.
class PinPickerPage extends StatefulWidget {
  const PinPickerPage({super.key, required this.existing, required this.api});
  final List<GalaLocation> existing;
  final ApiService api;
  @override
  State<PinPickerPage> createState() => _PinPickerPageState();
}

class _PinPickerPageState extends State<PinPickerPage> {
  final nameController = TextEditingController();
  LatLng? pin;
  bool looking = false;
  int lookupId = 0;
  String autoName = '';

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  Future<void> placePin(LatLng point) async {
    final id = ++lookupId;
    // Clear the name only if the user hasn't typed their own.
    if (nameController.text.trim().isEmpty ||
        nameController.text == autoName) {
      nameController.clear();
      autoName = '';
    }
    setState(() {
      pin = point;
      looking = true;
    });
    try {
      final suggested = await widget.api.reverseGeocode(
        point.latitude,
        point.longitude,
      );
      if (!mounted || id != lookupId) return;
      if (suggested != null && nameController.text.trim().isEmpty) {
        autoName = suggested;
        nameController.text = suggested;
      }
    } catch (_) {
      // The name is optional help; the user can type their own.
    }
    if (mounted && id == lookupId) setState(() => looking = false);
  }

  void confirm() {
    final point = pin;
    if (point == null) return;
    final typed = nameController.text.trim();
    Navigator.pop(
      context,
      GalaLocation(
        name: typed.isEmpty ? 'Pinned location' : typed,
        latitude: point.latitude,
        longitude: point.longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.existing
        .map((place) => LatLng(place.latitude, place.longitude))
        .toList();
    final temp = pin;
    return Scaffold(
      appBar: AppBar(title: const Text('Pin a location')),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: points.isNotEmpty
                        ? points.first
                        : defaultMapCenter,
                    initialZoom: points.isNotEmpty ? 15 : 11,
                    initialCameraFit: points.length > 1
                        ? CameraFit.coordinates(
                      coordinates: points,
                      padding: const EdgeInsets.all(72),
                      maxZoom: 16,
                    )
                        : null,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                    onTap: (_, point) => placePin(point),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.outly',
                    ),
                    if (points.isNotEmpty)
                      MarkerLayer(
                        markers: points
                            .map(
                              (point) => Marker(
                            point: point,
                            width: 36,
                            height: 36,
                            alignment: Alignment.topCenter,
                            child: const Icon(
                              Icons.location_pin,
                              color: plum,
                              size: 36,
                            ),
                          ),
                        )
                            .toList(),
                      ),
                    if (temp != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: temp,
                            width: 52,
                            height: 52,
                            alignment: Alignment.topCenter,
                            child: const Icon(
                              Icons.location_pin,
                              color: rose,
                              size: 52,
                            ),
                          ),
                        ],
                      ),
                    const RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution('OpenStreetMap contributors'),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: IgnorePointer(
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Text(
                          temp == null
                              ? 'Tap the map to drop a pin'
                              : 'Tap elsewhere to move the pin',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Material(
            elevation: 8,
            color: Colors.white,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      enabled: temp != null,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => confirm(),
                      decoration: InputDecoration(
                        labelText: 'Pin name',
                        hintText: temp == null
                            ? 'Drop a pin first'
                            : 'e.g. Rooftop bar',
                        prefixIcon: const Icon(Icons.label_outline),
                        suffixIcon: looking
                            ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          ),
                        )
                            : null,
                        fillColor: cream,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: temp == null ? null : confirm,
                        style: FilledButton.styleFrom(
                          backgroundColor: rose,
                          minimumSize: const Size.fromHeight(48),
                        ),
                        icon: const Icon(Icons.check),
                        label: const Text('Add this pin'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Participants
// ---------------------------------------------------------------------------

class ParticipantsPage extends StatelessWidget {
  const ParticipantsPage({
    super.key,
    required this.people,
    required this.store,
    required this.onChanged,
  });
  final List<Participant> people;
  final LocalStore store;
  final VoidCallback onChanged;
  Future<void> add(BuildContext context, [Participant? existing]) async {
    final name = TextEditingController(text: existing?.name);
    final email = TextEditingController(text: existing?.email);
    final result = await showDialog<Participant>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(existing == null ? 'Add participant' : 'Edit participant'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: email,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isEmpty || email.text.trim().isEmpty) {
                return;
              }
              Navigator.pop(
                context,
                Participant(
                  id: existing?.id,
                  name: name.text.trim(),
                  email: email.text.trim(),
                  availableDates: existing?.availableDates ?? const [],
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    name.dispose();
    email.dispose();
    if (result != null) {
      final list = [...people];
      final index = list.indexWhere((person) => person.id == result.id);
      if (index == -1) {
        list.add(result);
      } else {
        list[index] = result;
      }
      await store.saveParticipants(list);
      onChanged();
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Your people',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800, color: plum),
            ),
          ),
          IconButton(
            onPressed: () => add(context),
            icon: const Icon(Icons.person_add_alt_1, color: rose),
          ),
        ],
      ),
      const Text(
        'Keep contacts here so they can be invited to any gala.',
        style: TextStyle(color: Colors.black54),
      ),
      const SizedBox(height: 18),
      if (people.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('No participants yet.')),
          ),
        ),
      ...people.map(
            (person) => Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: rose.withAlpha(35),
              child: Text(
                person.name.isEmpty ? '?' : person.name[0].toUpperCase(),
                style: const TextStyle(
                  color: rose,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(person.name),
            subtitle: Text(person.email),
            trailing: IconButton(
              onPressed: () => add(context, person),
              icon: const Icon(Icons.edit_outlined),
            ),
          ),
        ),
      ),
    ],
  );
}