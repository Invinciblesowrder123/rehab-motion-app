import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'pages/chat_page.dart';
import 'pages/exercises_page.dart';

/// 应用入口
///
/// 使用 Riverpod 状态管理 + go_router 路由。
/// 两个页面：
/// - /           AI 问答（含安全提示、追问、回答）
/// - /exercises  动作库（按部位筛选 + 搜索 + 详情）
void main() => runApp(const ProviderScope(child: RehabApp()));

/// 路由配置
final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'chat',
      builder: (context, state) => const ChatPage(),
    ),
    GoRoute(
      path: '/exercises',
      name: 'exercises',
      builder: (context, state) => const ExercisesPage(),
    ),
  ],
);

class RehabApp extends StatelessWidget {
  const RehabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
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
      routerConfig: _router,
    );
  }
}
