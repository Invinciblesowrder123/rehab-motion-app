/// 应用配置
///
/// API 地址通过 `--dart-define=API_BASE_URL=...` 注入。
/// 默认值区分平台：
/// - Android 模拟器：10.0.2.2 映射到宿主机 localhost
/// - Web/桌面：localhost
/// - 真机：需指定实际 IP
class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 30);

  /// 安全免责声明（所有页面复用）
  static const String disclaimer =
      '本建议非医疗诊断，如有不适请停止并咨询治疗师。';

  /// 顶部安全提示
  static const String safetyBanner =
      '⚠️ 本工具不提供医疗诊断。如出现胸痛、突发无力、呼吸困难等症状，请立即就医。';
}
