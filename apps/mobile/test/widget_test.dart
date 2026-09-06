import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rehab_motion/main.dart';
import 'package:rehab_motion/models/chat_response.dart';
import 'package:rehab_motion/pages/urgent_widget.dart';
import 'package:rehab_motion/pages/answer_widget.dart';

void main() {
  group('RehabApp', () {
    testWidgets('renders app bar, safety banner, and input field',
        (WidgetTester tester) async {
      await tester.pumpWidget(const ProviderScope(child: RehabApp()));
      await tester.pumpAndSettle();

      expect(find.text('康复运动 · AI 问答'), findsOneWidget);
      expect(find.textContaining('本工具不提供医疗诊断'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('提问'), findsOneWidget);
    });

    testWidgets('shows empty state with example questions',
        (WidgetTester tester) async {
      await tester.pumpWidget(const ProviderScope(child: RehabApp()));
      await tester.pumpAndSettle();

      expect(find.text('请输入您的问题'), findsOneWidget);
      expect(find.textContaining('脑卒中后想了解上肢摆放'), findsOneWidget);
    });

    testWidgets('has reset button in app bar', (WidgetTester tester) async {
      await tester.pumpWidget(const ProviderScope(child: RehabApp()));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });
  });

  group('UrgentWidget', () {
    testWidgets('displays urgent message and matched rules',
        (WidgetTester tester) async {
      final chat = ChatResponse(
        type: 'urgent',
        message: '🚨 立即就医提示\n请立即停止训练并拨打 120。',
        severity: 3,
        matched: ['胸痛/心绞痛/胸部压榨感'],
        disclaimer: '本建议非医疗诊断，如有不适请停止并咨询治疗师。',
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: UrgentWidget(chat: chat)),
      ));

      expect(find.textContaining('立即就医提示'), findsOneWidget);
      expect(find.textContaining('拨打 120'), findsOneWidget);
      expect(find.textContaining('胸痛/心绞痛'), findsOneWidget);
      expect(find.byIcon(Icons.emergency), findsOneWidget);
    });
  });

  group('AnswerWidget', () {
    testWidgets('displays answer text and disclaimer', (WidgetTester tester) async {
      final chat = ChatResponse(
        type: 'answer',
        answer: '脑卒中亚急性期的良肢位摆放要点：\n1. 患侧上肢保持伸展...',
        disclaimer: '本建议非医疗诊断，如有不适请停止并咨询治疗师。',
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: AnswerWidget(chat: chat)),
      ));

      expect(find.textContaining('良肢位摆放'), findsOneWidget);
      expect(find.byIcon(Icons.smart_toy), findsOneWidget);
      expect(find.textContaining('非医疗诊断'), findsOneWidget);
    });
  });

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
  });
}
