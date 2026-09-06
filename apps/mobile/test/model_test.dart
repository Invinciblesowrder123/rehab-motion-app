import 'package:test/test.dart';
import 'package:rehab_motion/models/chat_response.dart';

void main() {
  group('ChatResponse', () {
    test('parses urgent response correctly', () {
      final json = {
        'type': 'urgent',
        'sessionId': 'abc-123',
        'message': '安全提示',
        'severity': 3,
        'matched': ['胸痛'],
        'disclaimer': '本建议非医疗诊断',
        'modelCalled': false,
      };
      final chat = ChatResponse.fromJson(json);

      expect(chat.type, 'urgent');
      expect(chat.severity, 3);
      expect(chat.matched, ['胸痛']);
      expect(chat.modelCalled, false);
      expect(chat.isUrgent, true);
      expect(chat.isAnswer, false);
    });

    test('parses clarify response correctly', () {
      final json = {
        'type': 'clarify',
        'sessionId': 'abc-456',
        'questions': [
          {
            'slot': 'stage',
            'question': '请问当前处于什么阶段？',
            'options': [
              {'label': '2 周内', 'value': 'acute'},
              {'label': '3 个月以上', 'value': 'chronic'},
            ],
          },
        ],
        'disclaimer': '本建议非医疗诊断',
        'modelCalled': false,
      };
      final chat = ChatResponse.fromJson(json);

      expect(chat.type, 'clarify');
      expect(chat.questions, hasLength(1));
      expect(chat.isClarify, true);
    });

    test('parses answer response correctly', () {
      final json = {
        'type': 'answer',
        'sessionId': 'abc-789',
        'answer': '建议做钟摆运动...',
        'referencedExercises': [
          {'id': '0521', 'name': '钟摆运动', 'level': 1},
        ],
        'sources': [
          {'book': '神经康复学(第3版)', 'chapter': 'ch02'},
        ],
        'disclaimer': '本建议非医疗诊断',
        'modelCalled': true,
      };
      final chat = ChatResponse.fromJson(json);

      expect(chat.type, 'answer');
      expect(chat.answer, contains('钟摆运动'));
      expect(chat.referencedExercises, hasLength(1));
      expect(chat.sources, hasLength(1));
      expect(chat.modelCalled, true);
      expect(chat.isAnswer, true);
    });

    test('parses error response', () {
      final json = {
        'type': 'error',
        'message': '网络错误',
      };
      final chat = ChatResponse.fromJson(json);
      expect(chat.isError, true);
    });
  });
}
