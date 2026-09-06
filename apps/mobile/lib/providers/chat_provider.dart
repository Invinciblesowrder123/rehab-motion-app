import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_response.dart';
import '../services/api_service.dart';

/// API service provider
final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

/// 聊天状态管理
///
/// 管理多轮会话的 sessionId 和当前响应状态。
/// 安全闸门逻辑在后端 NestJS，前端只负责按 type 分流渲染。
class ChatNotifier extends StateNotifier<AsyncValue<ChatResponse?>> {
  final ApiService _api;
  String? sessionId;

  ChatNotifier(this._api) : super(const AsyncValue.data(null));

  Future<void> send(String message, [Map<String, String>? slotAnswers]) async {
    state = const AsyncValue.loading();
    try {
      final json = await _api.postChat(
        message: message,
        sessionId: sessionId,
        slotAnswers: slotAnswers,
      );
      final chat = ChatResponse.fromJson(json);
      sessionId = chat.sessionId ?? sessionId;
      state = AsyncValue.data(chat);
    } on DioException catch (e) {
      state = AsyncValue.data(ChatResponse(
        type: 'error',
        message: '网络暂不可用：${e.message ?? '未知错误'}\n请检查后端服务是否已启动（默认端口 3000）。',
      ));
    } catch (e) {
      state = AsyncValue.data(ChatResponse(
        type: 'error',
        message: '发生未知错误：$e',
      ));
    }
  }

  /// 重置会话
  void reset() {
    sessionId = null;
    state = const AsyncValue.data(null);
  }
}

final chatProvider =
    StateNotifierProvider<ChatNotifier, AsyncValue<ChatResponse?>>(
  (ref) => ChatNotifier(ref.read(apiServiceProvider)),
);
