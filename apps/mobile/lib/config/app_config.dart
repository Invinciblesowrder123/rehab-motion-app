import 'package:flutter/foundation.dart' show kIsWeb;

/// API 地址通过 `--dart-define=API_BASE_URL=...` 注入。
///
/// 默认地址随运行端区分：
/// - Flutter Web / Windows 桌面端：localhost:3000
/// - Android 模拟器：10.0.2.2:3000 映射宿主机 localhost
/// - 真机：必须通过 --dart-define 指定电脑局域网 IP
class AppConfig {
  static const String _apiBaseUrlOverride = String.fromEnvironment('API_BASE_URL');

  static String get apiBaseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) return _apiBaseUrlOverride;
    return kIsWeb ? 'http://localhost:3000' : 'http://10.0.2.2:3000';
  }

  static const Duration connectTimeout = Duration(seconds: 15);
  /// 生成式回答依赖上游大模型，首字延迟实测 45–90s；
  /// 接收超时必须大于后端 AI_TIMEOUT_MS，否则用户侧会提前中断。
  static const Duration receiveTimeout = Duration(seconds: 240);

  /// 安全免责声明（所有页面复用）
  static const String disclaimer =
      '本建议非医疗诊断，如有不适请停止并咨询治疗师。';

  /// 顶部安全提示
  static const String safetyBanner =
      '⚠️ 本工具不提供医疗诊断。如出现胸痛、突发无力、呼吸困难等症状，请立即就医。';
}
