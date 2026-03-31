import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/entities.dart';
import '../services/nova_controller.dart';
import 'study_session_screen.dart';
import 'unit_editor_screen.dart';

class DictionaryDetailScreen extends StatefulWidget {
  const DictionaryDetailScreen({
    super.key,
    required this.dictionaryId,
    required this.dictionaryName,
  });

  final int dictionaryId;
  final String dictionaryName;

  @override
  State<DictionaryDetailScreen> createState() => _DictionaryDetailScreenState();
}

class _DictionaryDetailScreenState extends State<DictionaryDetailScreen> {
  late Future<List<CustomUnitSummary>> _future;
  final Set<int> _expandedUnits = <int>{};

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<CustomUnitSummary>> _load() {
    return context.read<NovaController>().repository.fetchUnits(
      widget.dictionaryId,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await context.read<NovaController>().refreshAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.dictionaryName)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addUnit,
        icon: const Icon(Icons.add),
        label: const Text('添加单元'),
      ),
      body: FutureBuilder<List<CustomUnitSummary>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final units = snapshot.data!;
          if (units.isEmpty) {
            return const Center(child: Text('这个词典还没有单元。'));
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
            itemCount: units.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final unit = units[index];
              final expanded = _expandedUnits.contains(unit.id);
              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF121E2D),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                unit.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text('${unit.wordCount} 个单词'),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              if (expanded) {
                                _expandedUnits.remove(unit.id);
                              } else {
                                _expandedUnits.add(unit.id);
                              }
                            });
                          },
                          icon: Icon(
                            expanded ? Icons.expand_less : Icons.expand_more,
                          ),
                        ),
                        IconButton(
                          onPressed: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => StudySessionScreen.custom(
                                  unitId: unit.id,
                                  unitName: unit.name,
                                ),
                              ),
                            );
                            if (context.mounted) {
                              await _refresh();
                            }
                          },
                          icon: const Icon(Icons.play_circle_outline),
                        ),
                        IconButton(
                          onPressed: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => UnitEditorScreen(
                                  unitId: unit.id,
                                  unitName: unit.name,
                                ),
                              ),
                            );
                            if (context.mounted) {
                              await _refresh();
                            }
                          },
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          onPressed: () => _deleteUnit(unit.id, unit.name),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                    if (expanded) ...[
                      const SizedBox(height: 14),
                      if (unit.previewWords.isEmpty)
                        const Text('这个单元还没有单词。')
                      else
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: unit.previewWords
                                .map(
                                  (word) => Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Chip(label: Text(word)),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _addUnit() async {
    final controller = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加单元'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '例如：Unit 1'),
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
              await context.read<NovaController>().repository.addUnit(
                dictionaryId: widget.dictionaryId,
                name: text,
              );
              if (context.mounted) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (created == true && mounted) {
      await _refresh();
    }
  }

  Future<void> _deleteUnit(int unitId, String unitName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除单元'),
        content: Text('确定删除“$unitName”吗？'),
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

    if (confirmed == true && mounted) {
      await context.read<NovaController>().repository.deleteUnit(unitId);
      await _refresh();
    }
  }
}
