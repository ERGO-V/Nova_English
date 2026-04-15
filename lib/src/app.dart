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
          builder: (context, child) {
            return Stack(
              children: [
                child ?? const SizedBox.shrink(),
                if (controller.isImporting)
                  _ImportBlockingOverlay(
                    message: controller.importStatusText ?? '正在导入数据...',
                  ),
              ],
            );
          },
          home: const HomeShell(),
        );
      },
    );
  }
}

class _ImportBlockingOverlay extends StatelessWidget {
  const _ImportBlockingOverlay({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        const ModalBarrier(
          dismissible: false,
          color: Color(0x88000000),
        ),
        Center(
          child: Container(
            width: 220,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x24000000),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(strokeWidth: 3.2),
                ),
                const SizedBox(height: 18),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '请稍候，导入完成前暂时无法操作',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
