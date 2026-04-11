import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'src/app.dart';
import 'src/services/nova_controller.dart';
import 'src/services/nova_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }

  final repository = NovaRepository();
  final controller = NovaController(repository);
  await controller.initialize();

  runApp(
    ChangeNotifierProvider.value(
      value: controller,
      child: const NovaEnglishApp(),
    ),
  );
}
