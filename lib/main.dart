import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'features/telemetry/telemetry.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Before runApp, because an error thrown during the first frame is exactly
  // the kind worth catching. Does nothing on a build with no Firebase project
  // behind it, which includes every fresh clone.
  await TelemetryBoot.start();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFF0A0C0A),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const ProviderScope(child: JungleApp()));
}
