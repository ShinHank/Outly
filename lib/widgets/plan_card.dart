import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/schedule.dart';
import '../models/location.dart';
import '../models/weather_info.dart';
import '../theme/app_theme.dart';

/// The shareable plan image.
///
/// It is always drawn on a 360px-wide canvas and scaled to fit, so exports
/// look identical on every device. The height grows with the number of stops,
/// guests, tags and the length of the plan, but never drops below 3:4.
class PlanCard extends StatelessWidget {
  const PlanCard({
    super.key,
    required this.name,
    required this.date,
    this.endDate,
    required this.locations,
    required this.tags,
    required this.plan,
    this.weatherText = '',
    this.weatherCode = -1,
    this.guests = const [],
  });
  final String name;
  final DateTime date;

  /// Last day of a multi-day outing, or null for a single day.
  final DateTime? endDate;
  final List<GalaLocation> locations;
  final List<String> tags;
  final String plan;
  final String weatherText;
  final int weatherCode;

  /// Names of the people who are coming.
  final List<String> guests;

  static const _canvasWidth = 360.0;
  static const _minHeight = 480.0;
  static const _padding = 26.0;
  static const _stopGap = 12.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth.isFinite
          ? constraints.maxWidth
          : _canvasWidth;
      // A tight width makes FittedBox scale the canvas up or down to fit,
      // and the height follows the content.
      return SizedBox(
        width: width,
        child: FittedBox(
          fit: BoxFit.fitWidth,
          alignment: Alignment.topCenter,
          child: SizedBox(width: _canvasWidth, child: canvas()),
        ),
      );
    },
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

  Widget tagPill(String text) => DecoratedBox(
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

  /// One stop: a numbered badge, the day and time, and the place name.
  Widget stopTile(int index, bool multiDay, double tileWidth) {
    final stop = locations[index];
    final when = [
      if (multiDay) 'D${stopDay(stop, date) + 1}',
      if (stop.time.isNotEmpty) timeLabel(stop.time),
    ].join(' · ');
    return SizedBox(
      width: tileWidth,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
              '${index + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (when.isNotEmpty)
                  Text(
                    when,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                Text(
                  shortName(stop.name),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget canvas() {
    final multiDay = endDate != null && !sameDay(date, endDate!);
    final shownTags = tags.take(6).toList();
    final extraTags = tags.length - shownTags.length;
    final shownGuests = guests.take(40).toList();
    final extraGuests = guests.length - shownGuests.length;
    // Two columns of stops across the 308px of usable width.
    const contentWidth = _canvasWidth - _padding * 2;
    const tileWidth = (contentWidth - _stopGap) / 2;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _minHeight),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [brandDark, brand],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(_padding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              line(Icons.calendar_month_outlined, longDateRange(date, endDate)),
              if (weatherText.isNotEmpty)
                line(weatherIconFor(weatherCode), weatherText),
              const SizedBox(height: 20),
              if (locations.isNotEmpty) ...[
                caption('STOPS'),
                Wrap(
                  spacing: _stopGap,
                  runSpacing: 12,
                  children: [
                    for (var i = 0; i < locations.length; i++)
                      stopTile(i, multiDay, tileWidth),
                  ],
                ),
                const SizedBox(height: 20),
              ],
              if (shownTags.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ...shownTags.map(tagPill),
                    if (extraTags > 0) tagPill('+$extraTags'),
                  ],
                ),
                const SizedBox(height: 20),
              ],
              if (shownGuests.isNotEmpty) ...[
                caption("WHO'S COMING · ${guests.length}"),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ...shownGuests.map(tagPill),
                    if (extraGuests > 0) tagPill('+$extraGuests more'),
                  ],
                ),
                const SizedBox(height: 20),
              ],
              if (plan.trim().isNotEmpty) ...[
                caption('THE PLAN'),
                Text(
                  plan.trim(),
                  maxLines: 12,
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
    );
  }
}
