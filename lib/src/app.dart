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
                    progress: controller.importProgressValue,
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
  const _ImportBlockingOverlay({
    required this.message,
    required this.progress,
  });

  final String message;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = progress == null
        ? null
        : '${(progress!.clamp(0.0, 1.0) * 100).round()}%';

    return Stack(
      children: [
        const ModalBarrier(
          dismissible: false,
          color: Color(0x88000000),
        ),
        Center(
          child: Container(
            width: 280,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.8),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '正在导入',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (percent != null)
                      Text(
                        percent,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  message,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '导入完成前暂时无法操作，请稍候。',
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
