import 'package:flutter/material.dart';

import '../core/format.dart';
import '../models/location.dart';
import '../models/weather_info.dart';
import '../theme/app_theme.dart';

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

  Widget canvas() {
    final stops = locations.take(4).toList();
    final extraStops = locations.length - stops.length;
    final shownTags = tags.take(6).toList();
    final extraTags = tags.length - shownTags.length;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [brandDark, brand],
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
                                    stops[i].time.isEmpty
                                        ? shortName(stops[i].name)
                                        : '${timeLabel(stops[i].time)}  ${shortName(stops[i].name)}',
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
                            ...shownTags.map(tagPill),
                            if (extraTags > 0) tagPill('+$extraTags'),
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
