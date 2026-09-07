import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_response.dart';
import '../services/api_service.dart';

/// API service provider
final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

/// 一条对话消息
///
/// 既包括用户发送的内容，也包括 AI/后端的响应。
/// 整个会话历史 = [ChatMessage] 列表，对话流 UI 直接渲染这个列表。
class ChatMessage {
  final String role; // 'user' | 'assistant'
  final String text; // 显示用的文字内容
  final ChatResponse? response; // 后端响应（用户消息没有）
  final bool isLoading; // 助手消息正在等待响应

  const ChatMessage({
    required this.role,
    required this.text,
    this.response,
    this.isLoading = false,
  });

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';

  ChatMessage copyWith({
    String? role,
    String? text,
    ChatResponse? response,
    bool? isLoading,
  }) {
    return ChatMessage(
      role: role ?? this.role,
      text: text ?? this.text,
      response: response ?? this.response,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// 聊天状态管理
///
/// 维护完整的对话历史（[messages]），而不是只保留当前一条响应。
/// 后端逻辑无变化（安全闸门 + 追问 + AI 调用），前端只多记一份历史。
class ChatNotifier extends StateNotifier<ChatState> {
  final ApiService _api;

  ChatNotifier(this._api) : super(const ChatState.empty());

  String? get sessionId => state.sessionId;

  /// 发送消息（追加用户消息 + 占位的助手消息 → 等响应 → 填入）
  Future<void> send(String message, [Map<String, String>? slotAnswers]) async {
    final text = message.trim();

    // 只有真实文本才追加一条用户消息；纯追问（只带 slotAnswers）不新增用户气泡
    if (text.isNotEmpty) {
      state = state.copyWith(
        messages: [
          ...state.messages,
          ChatMessage(role: 'user', text: text),
        ],
      );
    }

    // 没有任何可发送内容则直接返回
    if (text.isEmpty && slotAnswers == null) return;

    // 追问时如果文本为空，尝试复用最后一条用户消息文本；都没有则传空字符串
    final String messageToSend = text.isNotEmpty ? text : (state.lastUserText ?? '');

    // 追加加载占位
    state = state.copyWith(
      messages: [
        ...state.messages,
        const ChatMessage(role: 'assistant', text: '', isLoading: true),
      ],
      isLoading: true,
    );

    try {
      final json = await _api.postChat(
        message: messageToSend,
        sessionId: state.sessionId,
        slotAnswers: slotAnswers,
      );
      final chat = ChatResponse.fromJson(json);
      _replaceLastAssistant(chat);
      state = state.copyWith(
        sessionId: chat.sessionId ?? state.sessionId,
        isLoading: false,
      );
    } on DioException catch (e) {
      _replaceLastAssistant(
        ChatResponse(
          type: 'error',
          message:
              '网络暂不可用：${e.message ?? '未知错误'}\n请检查后端服务是否已启动（默认端口 3000）。',
        ),
      );
      state = state.copyWith(isLoading: false);
    } catch (e) {
      _replaceLastAssistant(
        ChatResponse(
          type: 'error',
          message: '发生未知错误：$e',
        ),
      );
      state = state.copyWith(isLoading: false);
    }
  }

  void _replaceLastAssistant(ChatResponse chat) {
    if (state.messages.isEmpty) return;
    final newMessages = List<ChatMessage>.from(state.messages);
    final last = newMessages.last;
    if (last.isAssistant && last.isLoading) {
      newMessages[newMessages.length - 1] = ChatMessage(
        role: 'assistant',
        text: _extractDisplayText(chat),
        response: chat,
      );
    } else {
      newMessages.add(ChatMessage(
        role: 'assistant',
        text: _extractDisplayText(chat),
        response: chat,
      ));
    }
    state = state.copyWith(messages: newMessages);
  }

  /// 重置整个会话
  void reset() {
    state = const ChatState.empty();
  }
}

/// 完整聊天状态（不可变）
class ChatState {
  final List<ChatMessage> messages;
  final String? sessionId;
  final bool isLoading;

  const ChatState({
    required this.messages,
    this.sessionId,
    this.isLoading = false,
  });

  const ChatState.empty()
      : messages = const [],
        sessionId = null,
        isLoading = false;

  ChatState copyWith({
    List<ChatMessage>? messages,
    String? sessionId,
    bool? isLoading,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      sessionId: sessionId ?? this.sessionId,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  /// 找到最后一条用户消息的文本，用于追问时携带原问题
  String? get lastUserText {
    for (int i = messages.length - 1; i >= 0; i--) {
      if (messages[i].isUser) return messages[i].text;
    }
    return null;
  }
}

/// 把 ChatResponse 折成一行可显示的摘要文字（用于历史列表）
String _extractDisplayText(ChatResponse chat) {
  if (chat.isUrgent) return chat.message ?? '🚨 安全提示';
  if (chat.isClarify) {
    final questions = chat.questions ?? const [];
    if (questions.isEmpty) return '等待你的回答';
    final first = questions.first;
    if (first is Map<String, dynamic>) {
      return '${first['question'] ?? '请补充信息'}';
    }
    return '等待你的回答';
  }
  if (chat.isAnswer) return chat.answer ?? '';
  if (chat.isError) return chat.message ?? '出错';
  return chat.message ?? '';
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>(
  (ref) => ChatNotifier(ref.read(apiServiceProvider)),
);
