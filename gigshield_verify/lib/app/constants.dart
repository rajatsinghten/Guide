/// App-wide constants — single source of truth for config values.
class AppConstants {
  AppConstants._();

  /// Base URL for the GigShield backend.
  /// Change this to your AWS URL once deployed:
  ///   e.g. 'https://api.gigshield.in'
  /// USB debug (Android phone): keep localhost and run
  ///   adb reverse tcp:8000 tcp:8000
  /// Wi-Fi testing: override with your PC LAN IP using
  ///   --dart-define=API_BASE_URL=http://192.168.1.42:8000
  // static const String baseUrl = 'http://43.204.22.185:8000';
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  // SharedPreferences keys
  static const String prefJwt = 'gs_jwt';
  static const String prefWorkerJson = 'gs_worker';
  static const String prefVerified = 'gs_verified';
}
