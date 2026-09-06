import 'package:flutter/material.dart';
import '../models/chat_response.dart';

/// 错误提示页面
///
/// 网络异常或后端不可用时显示。
class ErrorWidgetPage extends StatelessWidget {
  final ChatResponse chat;

  const ErrorWidgetPage({super.key, required this.chat});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            SelectableText(
              chat.message ?? '未知错误',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Text(
              '排查步骤：\n'
              '1. 确认后端 API 已启动（端口 3000）\n'
              '2. 真机需使用电脑局域网 IP 而非 localhost\n'
              '3. 模拟器用 10.0.2.2 映射到宿主机',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
