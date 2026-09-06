import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../models/chat_response.dart';

/// 聊天回答页面
///
/// 后端返回 type=answer 时显示。
/// 包含：AI 回答正文 + 引用动作卡片 + 知识来源 + 免责声明。
class AnswerWidget extends StatelessWidget {
  final ChatResponse chat;

  const AnswerWidget({super.key, required this.chat});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.smart_toy, color: Colors.teal, size: 28),
                  SizedBox(width: 8),
                  Text('AI 回答',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              SelectableText(
                chat.answer ?? '',
                style: const TextStyle(fontSize: 14, height: 1.6),
              ),
              if (chat.referencedExercises != null &&
                  chat.referencedExercises!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('推荐动作',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                ...chat.referencedExercises!.map((ex) => _buildExerciseTile(ex)),
              ],
              if (chat.sources != null && chat.sources!.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('知识来源',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ...chat.sources!.map((s) => Text(
                      '· ${(s as Map<String, dynamic>)['book']} - ${s['chapter']}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    )),
              ],
              const SizedBox(height: 12),
              _DisclaimerBox(text: chat.disclaimer ?? AppConfig.disclaimer),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExerciseTile(dynamic ex) {
    final exercise = ex as Map<String, dynamic>;
    return ListTile(
      leading: const Icon(Icons.fitness_center, color: Colors.teal),
      title: Text(exercise['name'] as String? ?? ''),
      subtitle: Text('等级：${exercise['level'] ?? '未知'}'),
      dense: true,
    );
  }
}

class _DisclaimerBox extends StatelessWidget {
  final String text;
  const _DisclaimerBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
      ),
    );
  }
}
