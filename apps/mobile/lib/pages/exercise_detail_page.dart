import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';
import '../models/exercise.dart';
import '../providers/exercise_provider.dart';

/// 动作详情页
///
/// 显示中文步骤、风险提示、建议剂量。
/// 步骤来自数据库（stesps_zh JSONB），不是 AI 生成的。
class ExerciseDetailPage extends ConsumerWidget {
  final String exerciseId;

  const ExerciseDetailPage({super.key, required this.exerciseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncExercise = ref.watch(exerciseDetailProvider(exerciseId));

    return Scaffold(
      appBar: AppBar(title: const Text('动作详情')),
      body: asyncExercise.when(
        data: (exercise) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题 + 等级
              Row(
                children: [
                  Expanded(
                    child: Text(
                      exercise.displayName,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                  _LevelBadge(exercise: exercise),
                ],
              ),
              if (exercise.nameEn != null) ...[
                const SizedBox(height: 4),
                Text(
                  exercise.nameEn!,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
              const SizedBox(height: 16),

              // 基本信息
              _InfoSection(exercise: exercise),
              const SizedBox(height: 16),

              // 动作步骤
              if (exercise.instructionZh != null &&
                  exercise.instructionZh!.isNotEmpty) ...[
                const _SectionTitle(title: '动作说明'),
                const SizedBox(height: 8),
                Text(
                  exercise.instructionZh!,
                  style: const TextStyle(fontSize: 14, height: 1.6),
                ),
                const SizedBox(height: 16),
              ],

              // 分步步骤
              if (exercise.stepsZh != null && exercise.stepsZh!.isNotEmpty) ...[
                const _SectionTitle(title: '操作步骤'),
                const SizedBox(height: 8),
                ...exercise.stepsZh!.asMap().entries.map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.teal.shade100,
                            child: Text(
                              '${entry.key + 1}',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.teal.shade800),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.value.toString(),
                              style: const TextStyle(fontSize: 14, height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 16),
              ],

              // 风险提示
              if (exercise.riskFlags != null &&
                  exercise.riskFlags!.isNotEmpty) ...[
                const _SectionTitle(title: '风险提示'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: exercise.riskFlags!
                      .map((flag) => Chip(
                            label: Text(flag),
                            backgroundColor: Colors.orange.shade50,
                            labelStyle: TextStyle(
                                fontSize: 12, color: Colors.orange.shade800),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
              ],

              // 分级依据
              if (exercise.rehabReason != null) ...[
                const _SectionTitle(title: '分级依据'),
                const SizedBox(height: 8),
                Text(
                  exercise.rehabReason!,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 16),
              ],

              // 免责声明
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber,
                            size: 18, color: Colors.orange.shade800),
                        const SizedBox(width: 6),
                        Text(
                          '安全提示',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '动作等级仅反映器械与动作本身的风险，不代表适合您的个体情况。\n'
                      '开始前请确认无疼痛、无不适；过程中如出现不适应立即停止。',
                      style: TextStyle(fontSize: 13, height: 1.5),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      AppConfig.disclaimer,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('无法加载动作详情'),
                const SizedBox(height: 8),
                Text(
                  '$e',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  final Exercise exercise;
  const _LevelBadge({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final isSafe = exercise.rehabLevel == 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isSafe ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSafe ? Colors.green.shade200 : Colors.orange.shade200,
        ),
      ),
      child: Text(
        '${exercise.rehabLevel ?? '?'} 级 · ${exercise.levelLabel}',
        style: TextStyle(
          fontSize: 12,
          color: isSafe ? Colors.green.shade800 : Colors.orange.shade800,
        ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final Exercise exercise;
  const _InfoSection({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('身体部位', exercise.bodyPart ?? '-'),
      ('目标肌群', exercise.targetMuscle ?? '-'),
      ('器械', exercise.equipment ?? '自重'),
      if (exercise.doseRecommend != null)
        ('建议剂量', exercise.doseRecommend!),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: rows
              .map((row) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 80,
                          child: Text(
                            row.$1,
                            style: const TextStyle(
                                fontSize: 13, color: Colors.grey),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            row.$2,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
  }
}
