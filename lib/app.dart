import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'utils/app_theme.dart';

class CourtStrengthApp extends StatelessWidget {
  const CourtStrengthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Court Strength',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      darkTheme: buildAppTheme(),
      themeMode: ThemeMode.dark,
      home: const HomeScreen(),
    );
  }
}
