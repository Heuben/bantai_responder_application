class AppConfig {
  const AppConfig({
    required this.baseUrl,
    this.appName = 'BANTAI',
    this.environment = 'development',
    this.apiTimeout = const Duration(seconds: 20),
  });

  final String baseUrl;
  final String appName;
  final String environment;
  final Duration apiTimeout;

  bool get isProduction => environment.toLowerCase() == 'production';
  bool get isDevelopment =>
      environment.toLowerCase() == 'development' || environment.toLowerCase() == 'dev';

  static AppConfig _instance = const AppConfig(
    baseUrl: String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://localhost:3000/api',
    ),
    appName: String.fromEnvironment(
      'APP_NAME',
      defaultValue: 'BANTAI',
    ),
    environment: String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'development',
    ),
  );

  static AppConfig get instance => _instance;

  static void configure({
    String? baseUrl,
    String? appName,
    String? environment,
    Duration? apiTimeout,
  }) {
    final resolvedBaseUrl = (baseUrl ?? _instance.baseUrl)
        .trim()
        .replaceAll(RegExp(r'/+$'), '');

    _instance = AppConfig(
      baseUrl: resolvedBaseUrl,
      appName: appName ?? _instance.appName,
      environment: environment ?? _instance.environment,
      apiTimeout: apiTimeout ?? _instance.apiTimeout,
    );
  }
}
