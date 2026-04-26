import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/entities.dart';
import '../services/nova_controller.dart';
import '../theme/nova_theme.dart';

class StudySessionScreen extends StatefulWidget {
  const StudySessionScreen.builtin({
    super.key,
    required this.source,
    required this.reviewOnly,
  }) : unitId = null,
       unitName = null;

  const StudySessionScreen.custom({
    super.key,
    required this.unitId,
    required this.unitName,
  }) : source = null,
       reviewOnly = false;

  final BuiltinSource? source;
  final bool reviewOnly;
  final int? unitId;
  final String? unitName;

  bool get isCustom => unitId != null;

  String get title {
    if (isCustom) {
      return '${unitName ?? '单元'}学习';
    }
    return reviewOnly ? '${source!.label}复习' : '${source!.label}学习';
  }

  @override
  State<StudySessionScreen> createState() => _StudySessionScreenState();
}

class _StudySessionScreenState extends State<StudySessionScreen> {
  bool _loading = true;
  bool _finished = false;
  String? _emptyMessage;
  List<StudyEntry> _queue = <StudyEntry>[];
  bool _revealed = false;
  bool? _selectedRemembered;
  int _totalSeen = 0;
  int _correctCount = 0;
  int _wrongCount = 0;
  final Map<String, int> _wrongWords = <String, int>{};

  StudyEntry get _current => _queue.first;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final repo = context.read<NovaController>().repository;
    final entries = widget.isCustom
        ? await repo.startCustomUnitSession(widget.unitId!)
        : await repo.startBuiltinSession(
            source: widget.source!,
            reviewOnly: widget.reviewOnly,
          );

    if (!mounted) {
      return;
    }

    setState(() {
      _queue = entries;
      _loading = false;
      _emptyMessage = entries.isEmpty
          ? (widget.isCustom ? '这个单元还没有可学习的单词。' : '当前没有符合条件的单词。')
          : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_emptyMessage != null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Center(child: Text(_emptyMessage!)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: _finished ? _buildSummary(context) : _buildSession(context),
        ),
      ),
    );
  }

  Widget _buildSession(BuildContext context) {
    final palette = context.novaColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _MiniChip(label: '剩余 ${_queue.length}'),
            _MiniChip(label: '正确 $_correctCount'),
            _MiniChip(label: '错误 $_wrongCount'),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.surfaceMuted,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(_revealed ? '选择无误后再确认，错题会重新插回本轮队列。' : '先判断自己是否认识，再查看释义。'),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              gradient: LinearGradient(
                colors: [palette.heroGradientStart, palette.heroGradientEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                RepaintBoundary(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.0, 0.15),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          )),
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      _current.word,
                      key: ValueKey<String>(_current.word),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _revealed ? 1.0 : 0.0,
                  child: Text(
                    _revealed ? _current.meaning : ' ',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Stack(
          alignment: Alignment.bottomCenter,
          children: [
            IgnorePointer(
              ignoring: _revealed,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: !_revealed ? 1.0 : 0.0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => _select(true),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('认识', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => _select(false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('不认识', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IgnorePointer(
              ignoring: !_revealed,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _revealed ? 1.0 : 0.0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _confirm,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: _selectedRemembered == true
                              ? Colors.green.shade600
                              : Colors.red.shade500,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(
                          _selectedRemembered == true ? '确认认识' : '确认不认识',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => _select(!(_selectedRemembered ?? false)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          _selectedRemembered == true ? '记错了，改为不认识' : '改为认识',
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummary(BuildContext context) {
    final palette = context.novaColors;
    final topWrong = _wrongWords.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '本轮完成',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              Text('总作答次数：$_totalSeen'),
              Text('正确次数：$_correctCount'),
              Text('错误次数：$_wrongCount'),
              const SizedBox(height: 16),
              if (topWrong.isEmpty)
                const Text('这一轮没有错题。')
              else ...[
                const Text(
                  '高频错词',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                ...topWrong
                    .take(5)
                    .map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('${entry.key} · ${entry.value} 次'),
                      ),
                    ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('返回'),
        ),
      ],
    );
  }

  void _select(bool remembered) {
    setState(() {
      _selectedRemembered = remembered;
      _revealed = true;
    });
  }

  Future<void> _confirm() async {
    final remembered = _selectedRemembered;
    if (remembered == null) {
      return;
    }

    final entry = _queue.removeAt(0);
    final repo = context.read<NovaController>().repository;

    if (entry.wordType == WordType.builtin) {
      await repo.applyBuiltinResult(entry, remembered);
    } else {
      await repo.applyCustomResult(entry, remembered);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _totalSeen += 1;
      if (remembered) {
        _correctCount += 1;
      } else {
        _wrongCount += 1;
        _wrongWords.update(entry.word, (value) => value + 1, ifAbsent: () => 1);
        _queue.add(entry);
      }

      _revealed = false;
      // 保留 _selectedRemembered 的旧值以确保在退出动画的 200ms 内按钮颜色不突变
      _finished = _queue.isEmpty;
    });
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.novaColors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: palette.chipBackground,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label),
    );
  }
}
