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
