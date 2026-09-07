import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/app_config.dart';
import '../models/chat_response.dart';
import '../providers/chat_provider.dart';
import 'answer_widget.dart';
import 'clarify_widget.dart';
import 'error_widget.dart';
import 'urgent_widget.dart';

/// 聊天主页面（对话流 UI）
///
/// 顶部常驻安全提示 → 可滚动的消息列表（用户气泡 + 助手卡片） → 底部输入区。
/// 助手消息按 type 分流：
/// - urgent / clarify_block → UrgentWidget
/// - clarify → ClarifyWidget（选择式追问）
/// - answer → AnswerWidget
/// - error → ErrorWidgetPage
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
    if (slotAnswers == null) _controller.clear();

    final notifier = ref.read(chatProvider.notifier);
    await notifier.send(text, slotAnswers);

    _scrollToBottom();
  }

  void _scrollToBottom() {
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
    final chatState = ref.watch(chatProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('康复运动 · AI 问答'),
        actions: [
          IconButton(
            icon: const Icon(Icons.fitness_center),
            tooltip: '动作库',
            onPressed: () => context.push('/exercises'),
          ),
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
            // 消息列表
            Expanded(
              child: Scrollbar(
                controller: _scrollController,
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  itemCount: chatState.messages.isEmpty
                      ? 1 // 空状态占位
                      : chatState.messages.length,
                  itemBuilder: (context, index) {
                    if (chatState.messages.isEmpty) {
                      return const _EmptyState();
                    }
                    final msg = chatState.messages[index];
                    if (msg.isUser) return _UserBubble(msg: msg);
                    return _AssistantCard(
                      msg: msg,
                      onAnswer: (slotAnswers) => _send(slotAnswers),
                    );
                  },
                ),
              ),
            ),
            // 输入区
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      maxLines: 3,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: '例如：脑卒中后想了解上肢摆放',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  chatState.isLoading
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

/// 用户消息气泡
class _UserBubble extends StatelessWidget {
  final ChatMessage msg;

  const _UserBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
          ),
        ),
        child: Text(
          msg.text,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

/// 助手消息卡片
class _AssistantCard extends StatelessWidget {
  final ChatMessage msg;
  final Future<void> Function(Map<String, String>) onAnswer;

  const _AssistantCard({required this.msg, required this.onAnswer});

  @override
  Widget build(BuildContext context) {
    final response = msg.response;

    // 加载中占位
    if (msg.isLoading || response == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 10),
              Text('正在思考…', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    final chat = response;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.92,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        child: _buildAssistantContent(chat),
      ),
    );
  }

  Widget _buildAssistantContent(ChatResponse chat) {
    if (chat.isUrgent) {
      return UrgentWidget(chat: chat);
    }
    if (chat.isClarify) {
      return ClarifyWidget(chat: chat, onAnswer: onAnswer);
    }
    if (chat.isAnswer) {
      return AnswerWidget(chat: chat);
    }
    return ErrorWidgetPage(chat: chat);
  }
}

/// 空状态（首次进入）
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 64),
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
      ),
    );
  }
}
