import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A titled block of content used on the detail and editor pages.
Widget section(String title, List<Widget> children, {IconData? icon}) =>
    Builder(
      builder: (context) => Padding(
        padding: const EdgeInsets.only(top: 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: context.brandColor),
                  const SizedBox(width: 8),
                ],
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );

Widget infoRow(IconData icon, String text) => Builder(
  builder: (context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: context.brandColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13.5),
          ),
        ),
      ],
    ),
  ),
);

/// Small coloured pill. Defaults to the brand green.
Widget pill(
  String text, {
  Color? color,
  Color? background,
  IconData? icon,
}) => Builder(
  builder: (context) {
    final fg = color ?? context.brandColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background ?? fg.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  },
);

/// Status gets its own colour so it reads at a glance.
Widget statusPill(String status) => Builder(
  builder: (context) {
    final color = switch (status) {
      'Confirmed' => context.brandColor,
      'Completed' => context.muted,
      'Cancelled' => const Color(0xFFE05545),
      _ => const Color(0xFFD98A00),
    };
    return pill(status, color: color);
  },
);

/// Muted helper text under fields.
class HintText extends StatelessWidget {
  const HintText(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(color: context.muted, fontSize: 12.5, height: 1.35),
  );
}

/// Padded card with a message, used for empty states.
class MessageCard extends StatelessWidget {
  const MessageCard(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Text(text, style: TextStyle(color: context.muted, height: 1.4)),
    ),
  );
}

/// First letter of a name for avatars, or "?" when empty.
String initialOf(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  return String.fromCharCode(trimmed.runes.first).toUpperCase();
}

/// Overlapping initial avatars. [ring] should match what they sit on.
class AvatarStack extends StatelessWidget {
  const AvatarStack({
    super.key,
    required this.names,
    required this.ring,
    this.size = 32,
    this.max = 4,
  });
  final List<String> names;
  final Color ring;
  final double size;
  final int max;

  @override
  Widget build(BuildContext context) {
    final shown = names.take(max).toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    final step = size * 0.75;
    return SizedBox(
      height: size,
      width: size + (shown.length - 1) * step,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * step,
              child: Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: avatarColors[i % avatarColors.length],
                  shape: BoxShape.circle,
                  border: Border.all(color: ring, width: 2),
                ),
                child: Text(
                  initialOf(shown[i]),
                  style: const TextStyle(
                    color: inkColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Mint "Local business" badge shown on independent local stops.
Widget localBadge() => Builder(
  builder: (context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
      color: context.mint,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      'Local business',
      style: TextStyle(
        color: context.onMint,
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    ),
  ),
);

/// The coral circle that peeks out of the corner of blue headers.
Widget coralCircle(double size) => Container(
  width: size,
  height: size,
  decoration: const BoxDecoration(color: coral, shape: BoxShape.circle),
);

/// Filter / day-tab pill. Selected is solid ink, unselected is a white pill.
class ChoicePill extends StatelessWidget {
  const ChoicePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: Material(
      color: selected ? context.ink : context.surfaceColor,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: SizedBox(
          height: 40,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? context.onInk : context.muted,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
