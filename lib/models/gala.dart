import 'dart:convert';
import 'dart:typed_data';

import '../core/schedule.dart';
import 'expense.dart';
import 'location.dart';

class Gala {
  Gala({
    String? id,
    required this.name,
    required this.date,
    this.endDate,
    required this.location,
    this.locations = const [],
    this.latitude = 0,
    this.longitude = 0,
    this.status = 'Planned',
    this.plan = '',
    this.tags = const [],
    this.weather = '',
    this.weatherCode = -1,
    this.thumbnail = '',
    this.participantIds = const [],
    this.expenses = const [],
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();
  final String id;
  final String name;
  final DateTime date;

  /// Last day of a multi-day outing. Null for a single-day outing.
  final DateTime? endDate;
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

  /// Base64 PNG of the plan image, captured when the gala is saved.
  final String thumbnail;
  final List<String> participantIds;

  final List<Expense> expenses;

  late final Uint8List? thumbnailBytes = () {
    if (thumbnail.isEmpty) return null;
    try {
      return base64Decode(thumbnail);
    } on FormatException {
      return null;
    }
  }();

  DateTime get startDay => DateTime(date.year, date.month, date.day);

  DateTime get lastDay {
    final end = endDate;
    if (end == null) return startDay;
    final day = DateTime(end.year, end.month, end.day);
    return day.isBefore(startDay) ? startDay : day;
  }

  int get dayCount =>
      DateTime.utc(lastDay.year, lastDay.month, lastDay.day)
          .difference(DateTime.utc(startDay.year, startDay.month, startDay.day))
          .inDays +
      1;

  bool get isMultiDay => dayCount > 1;

  /// True when the two outings share at least one day.
  bool overlaps(Gala other) =>
      !lastDay.isBefore(other.startDay) && !other.lastDay.isBefore(startDay);

  /// Locations sorted by day and time, including older galas that only
  /// stored one coordinate.
  List<GalaLocation> get places {
    if (locations.isNotEmpty) return sortStops(locations, date);
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

  /// Stops that are independent local businesses (SDG 8).
  int get localStops => places.where((place) => place.local).length;

  Gala copyWith({
    DateTime? date,
    String? weather,
    int? weatherCode,
    List<Expense>? expenses,
    List<GalaLocation>? locations,
  }) => Gala(
    id: id,
    name: name,
    date: date ?? this.date,
    endDate: endDate,
    location: location,
    locations: locations ?? this.locations,
    latitude: latitude,
    longitude: longitude,
    status: status,
    plan: plan,
    tags: tags,
    weather: weather ?? this.weather,
    weatherCode: weatherCode ?? this.weatherCode,
    thumbnail: thumbnail,
    participantIds: participantIds,
    expenses: expenses ?? this.expenses,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'scheduledDate': date.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'location': location,
    'locations': locations.map((item) => item.toJson()).toList(),
    'latitude': latitude,
    'longitude': longitude,
    'status': status,
    'plan': plan,
    'tags': tags,
    'weather': weather,
    'weatherCode': weatherCode,
    'thumbnail': thumbnail,
    'participantIds': participantIds,
    'expenses': expenses.map((item) => item.toJson()).toList(),
  };

  factory Gala.fromJson(Map<String, dynamic> json) {
    // Older versions stored outing types as "genres". Fold them into tags.
    final tags = <String>[...((json['tags'] as List?) ?? []).cast<String>()];
    for (final genre in ((json['genres'] as List?) ?? []).cast<String>()) {
      if (!tags.any((tag) => tag.toLowerCase() == genre.toLowerCase())) {
        tags.add(genre);
      }
    }
    return Gala(
      id: json['id'] as String?,
      name: json['name'] as String? ?? '',
      date:
          DateTime.tryParse(json['scheduledDate'] as String? ?? '') ??
          DateTime.now(),
      endDate: DateTime.tryParse(json['endDate'] as String? ?? ''),
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
      thumbnail: json['thumbnail'] as String? ?? '',
      participantIds: ((json['participantIds'] as List?) ?? [])
          .cast<String>(),
      expenses: ((json['expenses'] as List?) ?? [])
          .map(
            (item) => Expense.fromJson((item as Map).cast<String, dynamic>()),
          )
          .toList(),
    );
  }
}
