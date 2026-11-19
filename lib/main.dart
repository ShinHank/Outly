import 'package:flutter/material.dart';

import 'app.dart';
import 'services/reminders.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Reminders.init();
  runApp(const OutlyApp());
}
