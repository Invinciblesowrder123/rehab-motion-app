/// AI 聊天响应数据模型
///
/// 对应 NestJS 后端 `POST /ai/chat` 的三种返回类型：
/// - urgent: 命中红旗症状，立即就医
/// - clarify_block: 严重度 2 阻断（如急性期）
/// - clarify: 信息不全，需要追问
/// - answer: 正常回答
/// - error: 前端网络异常
class ChatResponse {
  final String type;
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

  bool get isUrgent => type == 'urgent' || type == 'clarify_block';
  bool get isClarify => type == 'clarify';
  bool get isAnswer => type == 'answer';
  bool get isError => type == 'error';
}
