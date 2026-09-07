import 'package:test/test.dart';
import 'package:rehab_motion/models/chat_response.dart';
import 'package:rehab_motion/models/exercise.dart';

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

  group('Exercise', () {
    test('parses exercise list item correctly', () {
      final json = {
        'id': '0521',
        'name_zh': '钟摆运动',
        'name_en': 'Pendulum Exercise',
        'body_part': 'shoulders',
        'equipment': 'body weight',
        'rehab_level': 1,
        'rehab_label': 'REHAB_SAFE',
        'rehab_reason': '自重，无器械风险',
      };
      final ex = Exercise.fromJson(json);

      expect(ex.id, '0521');
      expect(ex.displayName, '钟摆运动');
      expect(ex.rehabLevel, 1);
      expect(ex.levelLabel, '康复可用');
    });

    test('falls back to english name then id', () {
      expect(
        Exercise.fromJson({'id': '001', 'name_en': 'Bridge'}).displayName,
        'Bridge',
      );
      expect(
        Exercise.fromJson({'id': '002'}).displayName,
        '动作 002',
      );
    });

    test('level label for level 2 and unknown', () {
      expect(
        Exercise.fromJson({'id': '1', 'rehab_level': 2}).levelLabel,
        '需评估后使用',
      );
      expect(
        Exercise.fromJson({'id': '1'}).levelLabel,
        '未知等级',
      );
    });

    test('parses detail fields including steps', () {
      final json = {
        'id': '0521',
        'name_zh': '钟摆运动',
        'rehab_level': 1,
        'instruction_zh': '身体前倾，患侧手臂自然下垂。',
        'steps_zh': ['站立，健侧手扶桌沿', '身体前倾约 90 度', '患侧手臂画圈摆动'],
        'dose_recommend': '2组x10次，每日2次',
        'risk_flags': ['肩部负荷'],
      };
      final ex = Exercise.fromJson(json);

      expect(ex.instructionZh, contains('前倾'));
      expect(ex.stepsZh, hasLength(3));
      expect(ex.doseRecommend, contains('2组'));
      expect(ex.riskFlags, ['肩部负荷']);
    });

    test('parses exercise list response', () {
      final json = {
        'items': [
          {'id': '001', 'name_zh': '踝泵', 'rehab_level': 1},
          {'id': '002', 'name_zh': '直腿抬高', 'rehab_level': 2},
        ],
        'total': 2,
        'safetyPolicy': '仅返回 rehab_level <= 2',
      };
      final resp = ExerciseListResponse.fromJson(json);

      expect(resp.items, hasLength(2));
      expect(resp.total, 2);
      expect(resp.items.first.displayName, '踝泵');
      expect(resp.safetyPolicy, contains('rehab_level'));
    });

    test('handles empty and null items gracefully', () {
      expect(
        ExerciseListResponse.fromJson({'total': 0}).items,
        isEmpty,
      );
      expect(
        ExerciseListResponse.fromJson({}).total,
        0,
      );
    });
  });
}
