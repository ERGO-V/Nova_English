import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/nova_controller.dart';
import '../theme/nova_theme.dart';
import 'dictionary_detail_screen.dart';

class CustomDictionariesTab extends StatelessWidget {
  const CustomDictionariesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<NovaController>();
    final palette = context.novaColors;

    return Scaffold(
      appBar: AppBar(title: const Text('我的词典')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('添加词典'),
      ),
      body: controller.customDictionaries.isEmpty
          ? const Center(child: Text('还没有自定义词典，先创建一个开始吧。'))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
              itemCount: controller.customDictionaries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = controller.customDictionaries[index];
                return Container(
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    title: Text(
                      item.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${item.unitCount} 个单元 · ${item.wordCount} 个单词',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () =>
                          _confirmDelete(context, item.id, item.name),
                    ),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DictionaryDetailScreen(
                            dictionaryId: item.id,
                            dictionaryName: item.name,
                          ),
                        ),
                      );
                      if (context.mounted) {
                        await context.read<NovaController>().refreshAll();
                      }
                    },
                  ),
                );
              },
            ),
    );
  }

  Future<void> _showAddDialog(BuildContext context) async {
    final controller = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加词典'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '例如：Nova 高频词'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isEmpty) {
                return;
              }
              await context.read<NovaController>().addDictionary(text);
              if (context.mounted) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (created == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('词典已创建')));
    }
  }

  Future<void> _confirmDelete(BuildContext context, int id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除词典'),
        content: Text('确定删除“$name”吗？该词典下的单元和单词会一起删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<NovaController>().removeDictionary(id);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('词典已删除')));
      }
    }
  }
}
