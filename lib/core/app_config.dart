class AppConfig {
  static const appName = 'Smark Mart';
  static const packageName = 'com.hh.smart_mart';
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://smart-mart-v1.vercel.app',
  );

  static bool get hasApiBaseUrl => apiBaseUrl.trim().isNotEmpty;

  static String endpoint(String path) {
    final base = apiBaseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    return '$base$path';
  }
}
