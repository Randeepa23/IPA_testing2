import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:device_preview/device_preview.dart';

import 'splash_screen.dart';

void main() {
  runApp(
    DevicePreview(
      enabled: !kReleaseMode, // ON in debug, OFF in release
      builder: (context) => const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      // ✅ REQUIRED for DevicePreview
      useInheritedMediaQuery: true,
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,

      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),

      home: const SplashScreen(),
    );
  }
}
