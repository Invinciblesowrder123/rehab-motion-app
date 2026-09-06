import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../models/chat_response.dart';

/// 安全提示页面（urgent / clarify_block）
///
/// 命中红旗症状或急性期阻断时显示。
/// 红色卡片 + 急诊图标 + 命中规则列表 + 免责声明。
class UrgentWidget extends StatelessWidget {
  final ChatResponse chat;

  const UrgentWidget({super.key, required this.chat});

  @override
  Widget build(BuildContext context) {
    final isUrgent = chat.type == 'urgent';
    final color = isUrgent ? Colors.red : Colors.orange;
    final bg = isUrgent ? Colors.red.shade50 : Colors.orange.shade50;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        color: bg,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(isUrgent ? Icons.emergency : Icons.warning,
                      color: color, size: 32),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isUrgent ? '🚨 立即就医提示' : '⚠️ 暂停训练提示',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isUrgent
                            ? Colors.red.shade800
                            : Colors.orange.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                chat.message ?? '',
                style: const TextStyle(fontSize: 14, height: 1.6),
              ),
              if (chat.matched != null && chat.matched!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '命中规则：${chat.matched!.join('、')}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
              const SizedBox(height: 12),
              _DisclaimerBox(text: chat.disclaimer ?? AppConfig.disclaimer),
            ],
          ),
        ),
      ),
    );
  }
}

/// 免责声明小卡片（多个页面复用）
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
