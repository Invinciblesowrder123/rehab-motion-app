import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';
import '../models/exercise.dart';
import '../providers/exercise_provider.dart';
import 'exercise_detail_page.dart';

/// 动作库列表页
///
/// 顶部：部位筛选 + 搜索框
/// 中部：动作卡片列表（显示等级标签）
/// 安全：后端只返回 rehab_level <= 2，页面顶部常驻安全说明
class ExercisesPage extends ConsumerStatefulWidget {
  const ExercisesPage({super.key});

  @override
  ConsumerState<ExercisesPage> createState() => _ExercisesPageState();
}

class _ExercisesPageState extends ConsumerState<ExercisesPage> {
  final _searchController = TextEditingController();
  String _selectedPart = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncExercises = ref.watch(exerciseProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('动作库'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: () => ref
                .read(exerciseProvider.notifier)
                .load(bodyPart: _selectedPart, keyword: _searchController.text),
          ),
        ],
      ),
      body: Column(
        children: [
          // 安全说明条
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            color: Colors.teal.shade50,
            child: const Text(
              '🛡️ 本列表仅包含经安全筛选的动作（等级 ≤ 2）。'
              '是否适合您的具体情况，仍需治疗师或医生评估。',
              style: TextStyle(fontSize: 12, color: Colors.teal),
            ),
          ),
          // 搜索框
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索动作名称，如：臀桥',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    ref.read(exerciseProvider.notifier).load(keyword: '');
                  },
                ),
                border: const OutlineInputBorder(),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (value) =>
                  ref.read(exerciseProvider.notifier).load(keyword: value),
            ),
          ),
          // 部位筛选
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: bodyPartOptions.entries.map((entry) {
                final selected = _selectedPart == entry.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    label: Text(entry.key),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => _selectedPart = entry.value);
                      ref
                          .read(exerciseProvider.notifier)
                          .load(bodyPart: entry.value);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),
          // 列表
          Expanded(
            child: asyncExercises.when(
              data: (data) => data.items.isEmpty
                  ? const Center(
                      child: Text('没有找到匹配的动作',
                          style: TextStyle(color: Colors.grey)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: data.items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) =>
                          _ExerciseCard(exercise: data.items[index]),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorView(
                message: e is String ? e : '动作库暂不可用',
                onRetry: () => ref
                    .read(exerciseProvider.notifier)
                    .load(bodyPart: _selectedPart),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 动作卡片
class _ExerciseCard extends StatelessWidget {
  final Exercise exercise;
  const _ExerciseCard({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final isSafe = exercise.rehabLevel == 1;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isSafe ? Colors.green.shade100 : Colors.orange.shade100,
          child: Icon(
            Icons.fitness_center,
            color: isSafe ? Colors.green.shade700 : Colors.orange.shade700,
          ),
        ),
        title: Text(
          exercise.displayName,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '${exercise.bodyPart ?? '-'} · ${exercise.equipment ?? '自重'}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isSafe ? Colors.green.shade50 : Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSafe ? Colors.green.shade200 : Colors.orange.shade200,
            ),
          ),
          child: Text(
            exercise.levelLabel,
            style: TextStyle(
              fontSize: 11,
              color: isSafe ? Colors.green.shade800 : Colors.orange.shade800,
            ),
          ),
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ExerciseDetailPage(exerciseId: exercise.id),
          ),
        ),
      ),
    );
  }
}

/// 错误视图（数据库不可用时）
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.storage, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              '动作库暂不可用',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '需要启动数据库（PostgreSQL）。\n'
              '在项目目录执行：docker compose up -d postgres',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('重试')),
            const SizedBox(height: 12),
            Text(
              AppConfig.disclaimer,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
