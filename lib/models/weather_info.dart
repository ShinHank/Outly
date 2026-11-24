import 'package:flutter/material.dart';

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
