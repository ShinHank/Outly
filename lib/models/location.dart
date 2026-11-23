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
    this.time = '',
    this.local = false,
    this.date = '',
  });
  final String name;
  final double latitude;
  final double longitude;

  /// 24h "HH:mm", or empty when no time is set.
  final String time;

  /// The day of this stop as "yyyy-MM-dd". Empty means the first day.
  final String date;

  /// True for stops picked from the nearby suggestions that are independent
  /// local businesses (SDG 8).
  final bool local;

  GalaLocation copyWith({String? name, String? time, String? date}) =>
      GalaLocation(
        name: name ?? this.name,
        latitude: latitude,
        longitude: longitude,
        time: time ?? this.time,
        local: local,
        date: date ?? this.date,
      );

  Map<String, dynamic> toJson() => {
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
    'time': time,
    'local': local,
    'date': date,
  };

  factory GalaLocation.fromJson(Map<String, dynamic> json) => GalaLocation(
    name: json['name'] as String? ?? '',
    latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
    longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
    time: json['time'] as String? ?? '',
    local: json['local'] as bool? ?? false,
    date: json['date'] as String? ?? '',
  );
}
