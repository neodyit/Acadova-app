class AppConfig {
  static const String appName = 'Acadova';
  static const String appVersion = '1.0.0';

  // Local development backend URL options
  static const String localhostUrl = 'http://127.0.0.1:8000/api';
  static const String androidEmulatorUrl = 'http://10.0.2.2:8000/api';
  static const String lanDeviceUrl = 'http://10.200.51.26:8000/api';
  static const String tunnelUrl = 'https://represents-hub-prerequisite-sharon.trycloudflare.com/api';
  static const String xamppApacheUrl = 'http://localhost/Quiz%20App/backend/public/api';
  static const String productionUrl = 'https://acadova.neodyit.com/api';

  /// Primary API Base URL used by the Flutter app
  static String get apiBaseUrl {
    // Default directly to live production backend on acadova.neodyit.com
    return productionUrl;
  }

  /// Helper to override API URL dynamically for physical device testing
  static String customApiUrl = '';

  static String get activeApiUrl =>
      customApiUrl.isNotEmpty ? customApiUrl : apiBaseUrl;
}
