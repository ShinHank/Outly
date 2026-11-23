import 'package:latlong2/latlong.dart';

/// Nominatim's usage policy asks for a real contact. Put your own here.
const contactEmail = 'slimedipz@gmail.com';

/// Where the pin map opens when a gala has no locations yet.
const defaultMapCenter = LatLng(14.5995, 120.9842);

/// Symbol shown next to expense amounts.
const currency = '₱';

/// Stands in for the host in expenses (the host isn't in the people list).
const hostId = 'host';

const galaStatuses = ['Planned', 'Confirmed', 'Completed', 'Cancelled'];

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
