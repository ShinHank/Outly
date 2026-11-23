import 'package:flutter/material.dart';

import '../theme/theme_controller.dart';

/// App bar button to switch between system, light and dark themes.
class ThemeMenuButton extends StatelessWidget {
  const ThemeMenuButton({super.key});

  static const _options = [
    (ThemeMode.system, 'System default', Icons.brightness_auto_outlined),
    (ThemeMode.light, 'Light', Icons.light_mode_outlined),
    (ThemeMode.dark, 'Dark', Icons.dark_mode_outlined),
  ];

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
    valueListenable: themeController,
    builder: (context, mode, _) => PopupMenuButton<ThemeMode>(
      tooltip: 'Theme',
      icon: Icon(_options.firstWhere((o) => o.$1 == mode).$3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: themeController.set,
      itemBuilder: (_) => [
        for (final option in _options)
          CheckedPopupMenuItem<ThemeMode>(
            value: option.$1,
            checked: option.$1 == mode,
            child: Text(option.$2),
          ),
      ],
    ),
  );
}
