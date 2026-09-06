import 'package:dio/dio.dart';
import '../config/app_config.dart';

/// HTTP API 封装
///
/// 当前只有一个端点 `POST /ai/chat`，后续动作库查询也通过此 service。
class ApiService {
  final Dio _dio;

  ApiService()
      : _dio = Dio(BaseOptions(
          baseUrl: AppConfig.apiBaseUrl,
          connectTimeout: AppConfig.connectTimeout,
          receiveTimeout: AppConfig.receiveTimeout,
        ));

  /// 发送聊天消息
  ///
  /// [message] 用户输入文本
  /// [sessionId] 多轮会话标识（追问后带上）
  /// [slotAnswers] 用户回答追问的选择（如 {"stage": "subacute"}）
  Future<Map<String, dynamic>> postChat({
    required String message,
    String? sessionId,
    Map<String, String>? slotAnswers,
  }) async {
    final response = await _dio.post('/ai/chat', data: {
      'message': message,
      if (sessionId != null) 'sessionId': sessionId,
      if (slotAnswers != null) 'slotAnswers': slotAnswers,
    });
    return response.data as Map<String, dynamic>;
  }

  /// 健康检查
  Future<Map<String, dynamic>> getHealth() async {
    final response = await _dio.get('/health');
    return response.data as Map<String, dynamic>;
  }
}
