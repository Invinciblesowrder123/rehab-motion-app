import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';
import '../models/chat_response.dart';
import '../providers/chat_provider.dart';
import 'urgent_widget.dart';
import 'clarify_widget.dart';
import 'answer_widget.dart';
import 'error_widget.dart';

/// 聊天主页面
///
/// 顶部常驻安全提示 → 输入区 → 响应区（按 type 分流渲染）。
/// 响应区根据后端返回的 type 显示不同组件：
/// - urgent / clarify_block → UrgentWidget（安全提示）
/// - clarify → ClarifyWidget（选择式追问）
/// - answer → AnswerWidget（聊天回答）
/// - error → ErrorWidgetPage（错误提示）
class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send([Map<String, String>? slotAnswers]) async {
    final text = _controller.text.trim();
    if (text.isEmpty && slotAnswers == null) return;
    await ref.read(chatProvider.notifier).send(text, slotAnswers);
    if (slotAnswers != null) _controller.clear();
    // 滚动到底部
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final asyncChat = ref.watch(chatProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('康复运动 · AI 问答'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '重置会话',
            onPressed: () {
              ref.read(chatProvider.notifier).reset();
              _controller.clear();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 顶部安全提示
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.orange.shade50,
              child: const Text(
                AppConfig.safetyBanner,
                style: TextStyle(fontSize: 12, color: Colors.red),
              ),
            ),
            // 响应区（在输入区上方，占据剩余空间）
            Expanded(
              child: Scrollbar(
                controller: _scrollController,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  child: asyncChat.when(
                    data: (chat) => chat == null
                        ? _EmptyState()
                        : _ResponseWidget(chat: chat, onAnswer: _send),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('错误：$e')),
                  ),
                ),
              ),
            ),
            // 输入区
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      maxLines: 2,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: '例如：脑卒中后想了解上肢摆放',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  asyncChat.isLoading
                      ? const SizedBox(
                          width: 48,
                          height: 48,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : FilledButton(
                          onPressed: () => _send(),
                          child: const Text('提问'),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 空状态（首次进入）
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.health_and_safety, size: 64, color: Colors.teal.shade200),
          const SizedBox(height: 16),
          const Text(
            '请输入您的问题',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            '例如：\n• 脑卒中后想了解上肢摆放\n• 腰椎间盘突出能做什么运动\n• 膝关节术后怎么训练',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

/// 响应渲染组件（按 type 分流）
class _ResponseWidget extends StatelessWidget {
  final ChatResponse chat;
  final Future<void> Function(Map<String, String>) onAnswer;

  const _ResponseWidget({required this.chat, required this.onAnswer});

  @override
  Widget build(BuildContext context) {
    if (chat.isUrgent) return UrgentWidget(chat: chat);
    if (chat.isClarify) return ClarifyWidget(chat: chat, onAnswer: onAnswer);
    if (chat.isAnswer) return AnswerWidget(chat: chat);
    return ErrorWidgetPage(chat: chat);
  }
}
