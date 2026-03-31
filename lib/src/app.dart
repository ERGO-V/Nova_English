import 'package:flutter/material.dart';

import 'screens/home_shell.dart';

class NovaEnglishApp extends StatelessWidget {
  const NovaEnglishApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF12B4FF);

    return MaterialApp(
      title: 'NovaEnglish',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
          primary: seed,
          surface: const Color(0xFF101923),
        ),
        scaffoldBackgroundColor: const Color(0xFF09101A),
        cardColor: const Color(0xFF121E2D),
        textTheme: ThemeData.dark().textTheme.apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF132130),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
      ),
      home: const HomeShell(),
    );
  }
}
