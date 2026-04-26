import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../services/nova_controller.dart';
import '../theme/nova_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _nicknameController;

  @override
  void initState() {
    super.initState();
    final profile = context.read<NovaController>().profile;
    _nicknameController = TextEditingController(text: profile.nickname);
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<NovaController>();
    final palette = context.novaColors;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundImage: controller.avatarProvider(),
                  backgroundColor: palette.avatarBackground,
                  child: controller.avatarProvider() == null
                      ? const Icon(Icons.person_outline, size: 48)
                      : null,
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () =>
                          controller.pickAvatar(context, ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('相册'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () =>
                          controller.pickAvatar(context, ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('相机'),
                    ),
                    TextButton(
                      onPressed: controller.profile.avatarPath == null
                          ? null
                          : controller.clearAvatar,
                      child: const Text('移除头像'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _nicknameController,
                  decoration: const InputDecoration(labelText: '昵称'),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      await context.read<NovaController>().updateNickname(
                        _nicknameController.text,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(const SnackBar(content: Text('昵称已更新')));
                      }
                    },
                    child: const Text('保存资料'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _SettingGroup(
            title: '完整备份',
            children: [
              ListTile(
                leading: const Icon(Icons.upload_file_outlined),
                title: const Text('导出完整备份'),
                subtitle: const Text('包含内置学习进度、自定义词典、单元和单词'),
                onTap: () async {
                  final message = await context
                      .read<NovaController>()
                      .exportFullBackup();
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(message)));
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('导入完整备份'),
                subtitle: const Text('会合并备份内容，并恢复内置学习进度和自定义词典'),
                onTap: () async {
                  final confirmed = await _showConfirmDialog(
                    title: '导入完整备份',
                    content: '建议先导出当前数据再继续。导入后，内置学习进度会按备份内容覆盖合并。',
                  );
                  if (confirmed != true || !context.mounted) {
                    return;
                  }
                  final message = await context
                      .read<NovaController>()
                      .importFullBackup();
                  if (context.mounted && message != null) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(message)));
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SettingGroup(
            title: '自定义词典',
            children: [
              ListTile(
                leading: const Icon(Icons.file_upload_outlined),
                title: const Text('导出自定义词典'),
                subtitle: const Text('只导出自定义词典、单元和单词，不包含学习进度'),
                onTap: () async {
                  final message = await context
                      .read<NovaController>()
                      .exportCustomDictionaryBundle();
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(message)));
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.file_download_outlined),
                title: const Text('导入自定义词典'),
                subtitle: const Text('仅合并自定义词典内容，不覆盖当前学习进度'),
                onTap: () async {
                  final confirmed = await _showConfirmDialog(
                    title: '导入自定义词典',
                    content: '该操作只会导入自定义词典、单元和单词，当前学习进度保持不变。',
                  );
                  if (confirmed != true || !context.mounted) {
                    return;
                  }
                  final message = await context
                      .read<NovaController>()
                      .importCustomDictionaryBundle();
                  if (context.mounted && message != null) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(message)));
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SettingGroup(
            title: '显示',
            children: [
              SwitchListTile.adaptive(
                secondary: const Icon(Icons.light_mode_outlined),
                title: const Text('浅色主题'),
                subtitle: const Text('柔和米白与灰蓝配色，减少眩光'),
                value: controller.prefersLightTheme,
                onChanged: context.read<NovaController>().setPrefersLightTheme,
              ),
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('关于'),
                subtitle: Text('NovaEnglish 本地背词应用'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String content,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('继续'),
          ),
        ],
      ),
    );
  }
}

class _SettingGroup extends StatelessWidget {
  const _SettingGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = context.novaColors;

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}
