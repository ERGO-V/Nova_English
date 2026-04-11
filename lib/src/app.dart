import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/nova_controller.dart';
import 'screens/home_shell.dart';
import 'theme/nova_theme.dart';

class NovaEnglishApp extends StatelessWidget {
  const NovaEnglishApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NovaController>(
      builder: (context, controller, child) {
        return MaterialApp(
          title: 'NovaEnglish',
          debugShowCheckedModeBanner: false,
          theme: buildNovaTheme(Brightness.light),
          darkTheme: buildNovaTheme(Brightness.dark),
          themeMode: controller.themeMode,
          home: const HomeShell(),
        );
      },
    );
  }
}
