import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/entities.dart';
import '../services/nova_controller.dart';
import '../services/nova_repository.dart';
import '../theme/nova_theme.dart';

class UnitEditorScreen extends StatefulWidget {
  const UnitEditorScreen({
    super.key,
    required this.unitId,
    required this.unitName,
  });

  final int unitId;
  final String unitName;

  @override
  State<UnitEditorScreen> createState() => _UnitEditorScreenState();
}

class _UnitEditorScreenState extends State<UnitEditorScreen> {
  bool _loading = true;
  List<CustomWordDraft> _words = const [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final repo = context.read<NovaController>().repository;
    final words = await repo.fetchUnitWords(widget.unitId);
    if (!mounted) {
      return;
    }
    setState(() {
      _words = words;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.novaColors;

    return Scaffold(
      appBar: AppBar(
        title: Text('编辑 ${widget.unitName}'),
        actions: [TextButton(onPressed: _save, child: const Text('保存'))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addWord,
        icon: const Icon(Icons.add),
        label: const Text('添加单词'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _words.isEmpty
          ? const Center(child: Text('还没有单词，点击右下角开始添加。'))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
              itemCount: _words.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final word = _words[index];
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              word.word,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(word.meaning),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => _editWord(index),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _words = List.of(_words)..removeAt(index);
                          });
                        },
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Future<void> _addWord() async {
    final repo = context.read<NovaController>().repository;
    final result = await showDialog<CustomWordDraft>(
      context: context,
      builder: (_) => _WordEditorDialog(repository: repo),
    );
    if (result != null && mounted) {
      setState(() {
        _words = [..._words, result];
      });
    }
  }

  Future<void> _editWord(int index) async {
    final repo = context.read<NovaController>().repository;
    final result = await showDialog<CustomWordDraft>(
      context: context,
      builder: (_) =>
          _WordEditorDialog(repository: repo, initialWord: _words[index]),
    );
    if (result != null && mounted) {
      setState(() {
        final next = List<CustomWordDraft>.of(_words);
        next[index] = result;
        _words = next;
      });
    }
  }

  Future<void> _save() async {
    await context.read<NovaController>().repository.replaceUnitWords(
      unitId: widget.unitId,
      words: _words,
    );
    if (!mounted) {
      return;
    }
    Navigator.pop(context, true);
  }
}

class _WordEditorDialog extends StatefulWidget {
  const _WordEditorDialog({required this.repository, this.initialWord});

  final NovaRepository repository;
  final CustomWordDraft? initialWord;

  @override
  State<_WordEditorDialog> createState() => _WordEditorDialogState();
}

class _WordEditorDialogState extends State<_WordEditorDialog> {
  late final TextEditingController _wordController;
  late final TextEditingController _meaningController;
  List<OxfordEntry> _suggestions = const [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _wordController = TextEditingController(
      text: widget.initialWord?.word ?? '',
    );
    _meaningController = TextEditingController(
      text: widget.initialWord?.meaning ?? '',
    );
    _wordController.addListener(_search);
    if (_wordController.text.isNotEmpty) {
      _search();
    }
  }

  @override
  void dispose() {
    _wordController.dispose();
    _meaningController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _searching = true;
    });
    final results = await widget.repository.searchOxford(_wordController.text);
    if (!mounted) {
      return;
    }
    setState(() {
      _suggestions = results;
      _searching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialWord == null ? '添加单词' : '修改单词'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _wordController,
                autofocus: true,
                decoration: const InputDecoration(labelText: '英文单词'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _meaningController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: '中文释义'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('牛津词典匹配'),
                  const SizedBox(width: 8),
                  if (_searching)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (_suggestions.isEmpty)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('未找到匹配项，可手动填写释义。'),
                )
              else
                SizedBox(
                  height: 180,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _suggestions.length,
                    itemBuilder: (context, index) {
                      final item = _suggestions[index];
                      return ListTile(
                        dense: true,
                        title: Text(item.word),
                        subtitle: Text(item.meaning),
                        onTap: () {
                          _wordController.text = item.word;
                          _meaningController.text = item.meaning;
                          setState(() {
                            _suggestions = const [];
                          });
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final word = _wordController.text.trim();
            final meaning = _meaningController.text.trim();
            if (word.isEmpty || meaning.isEmpty) {
              return;
            }
            Navigator.pop(
              context,
              CustomWordDraft(
                id: widget.initialWord?.id,
                word: word,
                meaning: meaning,
              ),
            );
          },
          child: const Text('确定'),
        ),
      ],
    );
  }
}
