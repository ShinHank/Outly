import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/format.dart';
import '../models/gala.dart';

/// Local notifications: a nudge the day before (9am) and the morning of (8am).
/// Written for flutter_local_notifications 19.x. If you're on a different
/// major version, only init() and schedule() below should need tweaks.
class Reminders {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      );
      await _plugin.initialize(settings: settings);
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      _ready = true;
    } catch (_) {
      _ready = false; // Reminders are a bonus; never block the app.
    }
  }

  static int _hash(String s) {
    var h = 17;
    for (final c in s.codeUnits) {
      h = (h * 31 + c) & 0x3fffffff;
    }
    return h;
  }

  static int _id(String galaId, int slot) => _hash(galaId) * 2 + slot;

  static Future<void> cancel(String galaId) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: _id(galaId, 0));
      await _plugin.cancel(id: _id(galaId, 1));
    } catch (_) {}
  }

  static Future<void> schedule(Gala gala) async {
    if (!_ready) return;
    await cancel(gala.id);
    if (gala.status == 'Cancelled' || gala.status == 'Completed') return;

    final first = gala.places.isEmpty ? null : gala.places.first;
    final body = [
      if (first != null && first.time.isNotEmpty) timeLabel(first.time),
      if (first != null) shortName(first.name),
      if (gala.weather.isNotEmpty) gala.weather,
    ].join(' · ');

    final d = gala.date;
    final slots = <(int, DateTime, String)>[
      (0, DateTime(d.year, d.month, d.day - 1, 9), 'Tomorrow: ${gala.name}'),
      (1, DateTime(d.year, d.month, d.day, 8), 'Today: ${gala.name}'),
    ];
    final now = DateTime.now();
    for (final (slot, at, title) in slots) {
      if (!at.isAfter(now)) continue;
      try {
        await _plugin.zonedSchedule(
          id: _id(gala.id, slot),
          title: title,
          body: body.isEmpty ? 'Tap to see the plan.' : body,
          scheduledDate: tz.TZDateTime.from(at, tz.local),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'outly_reminders',
              'Gala reminders',
              channelDescription: 'Reminders before your galas',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } catch (_) {}
    }
  }
}
