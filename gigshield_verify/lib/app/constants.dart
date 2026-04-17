/// App-wide constants — single source of truth for config values.
class AppConstants {
  AppConstants._();

  /// Base URL for the GigShield backend.
  /// Change this to your AWS URL once deployed:
  ///   e.g. 'https://api.gigshield.in'
  /// For local dev on a physical device, use your Mac's LAN IP:
  ///   e.g. 'http://192.168.1.42:8000'
  static const String baseUrl = 'http://10.1.169.137:8000';

  // SharedPreferences keys
  static const String prefJwt = 'gs_jwt';
  static const String prefWorkerJson = 'gs_worker';
  static const String prefVerified = 'gs_verified';
}
