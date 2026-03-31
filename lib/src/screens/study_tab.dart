import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/entities.dart';
import '../services/nova_controller.dart';
import 'settings_screen.dart';
import 'study_session_screen.dart';

class StudyTab extends StatelessWidget {
  const StudyTab({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<NovaController>();
    final stats = controller.studyStats;

    return Scaffold(
      appBar: AppBar(
        title: const Text('学习'),
        leadingWidth: 80,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16, top: 6, bottom: 6),
          child: InkWell(
            borderRadius: BorderRadius.circular(40),
            onTap: () async {
              await Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
              if (context.mounted) {
                await context.read<NovaController>().refreshAll();
              }
            },
            child: CircleAvatar(
              backgroundImage: controller.avatarProvider(),
              backgroundColor: const Color(0xFF183249),
              child: controller.avatarProvider() == null
                  ? const Icon(Icons.person_outline)
                  : null,
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                colors: [Color(0xFF10273F), Color(0xFF0D1824)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hi, ${controller.profile.nickname}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text('今天继续把生词压进长期记忆里。'),
                const SizedBox(height: 20),
                DropdownButtonFormField<BuiltinSource>(
                  initialValue: controller.selectedSource,
                  decoration: const InputDecoration(labelText: '选择内置词典'),
                  items: BuiltinSource.values
                      .map(
                        (source) => DropdownMenuItem(
                          value: source,
                          child: Text(source.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      context.read<NovaController>().changeSource(value);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StatCard(
                title: '待掌握',
                value: '${stats.active}',
                subtitle: '仍在复习池',
              ),
              _StatCard(
                title: '待复习',
                value: '${stats.due}',
                subtitle: '已到复习时间',
              ),
              _StatCard(
                title: '已掌握',
                value: '${stats.mastered}',
                subtitle: '连续正确 3 次',
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF121E2D),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.insights_outlined),
                    const SizedBox(width: 10),
                    Text(
                      '当前进度 ${stats.mastered}/${stats.total}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: stats.completionRatio,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(999),
                  backgroundColor: const Color(0xFF203243),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => StudySessionScreen.builtin(
                            source: controller.selectedSource,
                            reviewOnly: false,
                          ),
                        ),
                      );
                      if (context.mounted) {
                        await context.read<NovaController>().refreshAll();
                      }
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('开始学习'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => StudySessionScreen.builtin(
                            source: controller.selectedSource,
                            reviewOnly: true,
                          ),
                        ),
                      );
                      if (context.mounted) {
                        await context.read<NovaController>().refreshAll();
                      }
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('复习'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF121E2D),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 10),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(subtitle),
          ],
        ),
      ),
    );
  }
}
