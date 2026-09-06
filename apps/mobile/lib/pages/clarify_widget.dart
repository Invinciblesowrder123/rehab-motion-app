import 'package:flutter/material.dart';
import '../models/chat_response.dart';

/// 选择式追问页面
///
/// 后端返回 type=clarify 时显示。
/// 渲染选择题（ActionChip），用户点击后带着 slotAnswers 重新提交。
/// 每次只问 1 个问题（后端控制），降低残障用户输入负担。
class ClarifyWidget extends StatelessWidget {
  final ChatResponse chat;
  final Future<void> Function(Map<String, String>) onAnswer;

  const ClarifyWidget({
    super.key,
    required this.chat,
    required this.onAnswer,
  });

  @override
  Widget build(BuildContext context) {
    final questions = chat.questions ?? [];

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
                  Icon(Icons.help_outline, color: Colors.teal, size: 28),
                  SizedBox(width: 8),
                  Text('补充信息',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                '为提供安全建议，请回答以下问题：',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ...questions.map((q) => _buildQuestion(q)),
              if (chat.disclaimer != null)
                Text(
                  chat.disclaimer!,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestion(dynamic q) {
    final question = q as Map<String, dynamic>;
    final slot = question['slot'] as String;
    final questionText = question['question'] as String;
    final options = question['options'] as List<dynamic>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          questionText,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((opt) {
            final option = opt as Map<String, dynamic>;
            return ActionChip(
              label: Text(option['label'] as String),
              onPressed: () => onAnswer({slot: option['value'] as String}),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
