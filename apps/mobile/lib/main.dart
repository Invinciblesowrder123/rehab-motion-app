import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ========================================================================== //
// 配置
// ========================================================================== //
// Android 模拟器用 10.0.2.2 映射到宿主机 localhost；真机用实际 IP。
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:3000',
);

final dioProvider = Provider<Dio>((ref) {
  return Dio(BaseOptions(
    baseUrl: apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
  ));
});

// ========================================================================== //
// 数据模型
// ========================================================================== //
class ChatResponse {
  final String type; // urgent | clarify_block | clarify | answer
  final String? sessionId;
  final String? message;
  final int? severity;
  final List<String>? matched;
  final List<dynamic>? questions;
  final String? answer;
  final List<dynamic>? referencedExercises;
  final List<dynamic>? sources;
  final String? disclaimer;
  final bool? modelCalled;

  ChatResponse({
    required this.type,
    this.sessionId,
    this.message,
    this.severity,
    this.matched,
    this.questions,
    this.answer,
    this.referencedExercises,
    this.sources,
    this.disclaimer,
    this.modelCalled,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) => ChatResponse(
        type: json['type'] as String,
        sessionId: json['sessionId'] as String?,
        message: json['message'] as String?,
        severity: json['severity'] as int?,
        matched: (json['matched'] as List<dynamic>?)?.cast<String>(),
        questions: json['questions'] as List<dynamic>?,
        answer: json['answer'] as String?,
        referencedExercises: json['referencedExercises'] as List<dynamic>?,
        sources: json['sources'] as List<dynamic>?,
        disclaimer: json['disclaimer'] as String?,
        modelCalled: json['modelCalled'] as bool?,
      );
}

// ========================================================================== //
// 聊天状态管理
// ========================================================================== //
class ChatState extends StateNotifier<AsyncValue<ChatResponse?>> {
  final Dio dio;
  String? sessionId;

  ChatState(this.dio) : super(const AsyncValue.data(null));

  Future<void> send(String message, [Map<String, String>? slotAnswers]) async {
    state = const AsyncValue.loading();
    try {
      final response = await dio.post('/ai/chat', data: {
        'message': message,
        if (sessionId != null) 'sessionId': sessionId,
        if (slotAnswers != null) 'slotAnswers': slotAnswers,
      });
      final chat = ChatResponse.fromJson(response.data as Map<String, dynamic>);
      sessionId = chat.sessionId ?? sessionId;
      state = AsyncValue.data(chat);
    } on DioException catch (e) {
      state = AsyncValue.data(ChatResponse(
        type: 'error',
        message: '网络暂不可用：${e.message ?? '未知错误'}。请检查后端服务是否已启动。',
      ));
    }
  }
}

final chatProvider = StateNotifierProvider<ChatState, AsyncValue<ChatResponse?>>(
  (ref) => ChatState(ref.read(dioProvider)),
);

// ========================================================================== //
// 主入口
// ========================================================================== //
void main() => runApp(const ProviderScope(child: RehabApp()));

class RehabApp extends StatelessWidget {
  const RehabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '康复运动',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: true),
      ),
      home: const ChatPage(),
    );
  }
}

// ========================================================================== //
// 聊天页面（核心：安全提示 + 选择式追问 + 聊天回答）
// ========================================================================== //
class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send([Map<String, String>? slotAnswers]) async {
    final text = _controller.text.trim();
    if (text.isEmpty && slotAnswers == null) return;
    await ref.read(chatProvider.notifier).send(text, slotAnswers);
    if (slotAnswers != null) _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final asyncChat = ref.watch(chatProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('康复运动 · AI 问答')),
      body: SafeArea(
        child: Column(
          children: [
            // 顶部安全免责声明
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.orange.shade50,
              child: const Text(
                '⚠️ 本工具不提供医疗诊断。如出现胸痛、突发无力、呼吸困难等症状，请立即就医。',
                style: TextStyle(fontSize: 12, color: Colors.red),
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
                      decoration: const InputDecoration(
                        hintText: '例如：脑卒中后想了解上肢摆放',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  asyncChat.isLoading
                      ? const CircularProgressIndicator()
                      : FilledButton(
                          onPressed: () => _send(),
                          child: const Text('提问'),
                        ),
                ],
              ),
            ),
            // 响应区
            Expanded(
              child: asyncChat.when(
                data: (chat) => chat == null
                    ? const Center(child: Text('请输入您的问题'))
                    : _ResponseWidget(chat: chat, onAnswer: _send),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('错误：$e')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ========================================================================== //
// 响应渲染组件（按 type 分流：urgent / clarify / answer）
// ========================================================================== //
class _ResponseWidget extends StatelessWidget {
  final ChatResponse chat;
  final Future<void> Function(Map<String, String>) onAnswer;

  const _ResponseWidget({required this.chat, required this.onAnswer});

  @override
  Widget build(BuildContext context) {
    switch (chat.type) {
      case 'urgent':
      case 'clarify_block':
        return _UrgentWidget(chat: chat);
      case 'clarify':
        return _ClarifyWidget(chat: chat, onAnswer: onAnswer);
      case 'answer':
        return _AnswerWidget(chat: chat);
      case 'error':
        return _ErrorWidget(chat: chat);
      default:
        return Center(child: Text('未知响应类型：${chat.type}'));
    }
  }
}

// --- 安全提示（urgent / clarify_block）---
class _UrgentWidget extends StatelessWidget {
  final ChatResponse chat;
  const _UrgentWidget({required this.chat});

  @override
  Widget build(BuildContext context) {
    final isUrgent = chat.type == 'urgent';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        color: isUrgent ? Colors.red.shade50 : Colors.orange.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(isUrgent ? Icons.emergency : Icons.warning,
                      color: isUrgent ? Colors.red : Colors.orange, size: 32),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isUrgent ? '🚨 立即就医提示' : '⚠️ 暂停训练提示',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isUrgent ? Colors.red.shade800 : Colors.orange.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(chat.message ?? '', style: const TextStyle(fontSize: 14, height: 1.6)),
              if (chat.matched != null && chat.matched!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('命中规则：${chat.matched!.join('、')}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  chat.disclaimer ?? '',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- 选择式追问 ---
class _ClarifyWidget extends StatelessWidget {
  final ChatResponse chat;
  final Future<void> Function(Map<String, String>) onAnswer;
  const _ClarifyWidget({required this.chat, required this.onAnswer});

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
                  Text('补充信息', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 4),
              const Text('为提供安全建议，请回答以下问题：',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 16),
              ...questions.map((q) {
                final question = q as Map<String, dynamic>;
                final slot = question['slot'] as String;
                final questionText = question['question'] as String;
                final options = question['options'] as List<dynamic>;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(questionText, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
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
              }),
              if (chat.disclaimer != null)
                Text(chat.disclaimer!, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),
        ),
      ),
    );
  }
}

// --- 聊天回答 ---
class _AnswerWidget extends StatelessWidget {
  final ChatResponse chat;
  const _AnswerWidget({required this.chat});

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
                  Text('AI 回答', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              Text(chat.answer ?? '', style: const TextStyle(fontSize: 14, height: 1.6)),
              if (chat.referencedExercises != null && chat.referencedExercises!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('推荐动作', style: TextStyle(fontWeight: FontWeight.bold)),
                ...chat.referencedExercises!.map((ex) => ListTile(
                      leading: const Icon(Icons.fitness_center),
                      title: Text((ex as Map<String, dynamic>)['name'] as String? ?? ''),
                      subtitle: Text('等级：${ex['level'] ?? '未知'}'),
                    )),
              ],
              if (chat.sources != null && chat.sources!.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('知识来源', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ...chat.sources!.map((s) => Text(
                      '· ${(s as Map<String, dynamic>)['book']} - ${s['chapter']}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    )),
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  chat.disclaimer ?? '',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- 错误提示 ---
class _ErrorWidget extends StatelessWidget {
  final ChatResponse chat;
  const _ErrorWidget({required this.chat});

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
            Text(chat.message ?? '未知错误', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
