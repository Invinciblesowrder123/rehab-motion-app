import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'pages/chat_page.dart';

/// 应用入口
///
/// 使用 Riverpod 状态管理。
/// 当前 MVP 阶段只有单页面（ChatPage），后续可加 go_router 路由：
/// - /chat    聊天问答
/// - /exercises 动作库列表
/// - /plans    训练方案
/// - /profile  个人中心
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
        // 无障碍：默认字体偏大，适合老年和视障用户
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 15),
        ),
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const ChatPage(),
    );
  }
}
