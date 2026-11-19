import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

class OutlyApp extends StatelessWidget {
  const OutlyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Outly',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(Brightness.light),
    darkTheme: buildTheme(Brightness.dark),
    // Follows the phone's light/dark setting.
    themeMode: ThemeMode.system,
    home: const HomeScreen(),
  );
}
