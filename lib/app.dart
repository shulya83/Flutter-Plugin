import 'package:flutter/material.dart';

import 'screens/focus_overlay_dashboard.dart';

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Windows Text Overlay Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E7A5F),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F7F9),
        useMaterial3: true,
      ),
      home: const FocusOverlayDashboard(),
    );
  }
}
