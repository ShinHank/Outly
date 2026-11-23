import 'package:flutter/material.dart';

import 'app.dart';
import 'services/reminders.dart';
import 'theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Reminders.init();
  await themeController.load();
  runApp(const OutlyApp());
}
