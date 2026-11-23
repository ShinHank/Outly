import 'dart:math' as math;

/// Great-circle distance between two coordinates, in km.
double distanceKm(double lat1, double lon1, double lat2, double lon2) {
  const earthKm = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLon = rad(lon2 - lon1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLon / 2), 2);
  return earthKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

String distanceLabel(double km) =>
    km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(1)} km';
