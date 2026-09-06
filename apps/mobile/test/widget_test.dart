import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rehab_motion/main.dart';

void main() {
  testWidgets('App renders safety disclaimer and input field', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: RehabApp()));
    await tester.pumpAndSettle();
    expect(find.text('康复运动 · AI 问答'), findsOneWidget);
    expect(find.textContaining('本工具不提供医疗诊断'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
