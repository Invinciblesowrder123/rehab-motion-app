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

  /// 查询动作库
  ///
  /// 注意：后端只返回 rehab_level <= 2 的动作（3 级高危永不返回）。
  /// [bodyPart] 按身体部位筛选（如 waist / shoulders）
  /// [keyword] 按中英文名称模糊搜索
  Future<Map<String, dynamic>> getExercises({
    String? bodyPart,
    String? keyword,
    int limit = 30,
  }) async {
    final response = await _dio.get(
      '/exercises',
      queryParameters: {
        if (bodyPart != null) 'bodyPart': bodyPart,
        if (keyword != null && keyword.isNotEmpty) 'q': keyword,
        'limit': limit.toString(),
      },
    );
    return response.data as Map<String, dynamic>;
  }

  /// 查询动作详情
  Future<Map<String, dynamic>> getExerciseDetail(String id) async {
    final response = await _dio.get('/exercises/$id');
    return response.data as Map<String, dynamic>;
  }

  /// 健康检查
  Future<Map<String, dynamic>> getHealth() async {
    final response = await _dio.get('/health');
    return response.data as Map<String, dynamic>;
  }
}
