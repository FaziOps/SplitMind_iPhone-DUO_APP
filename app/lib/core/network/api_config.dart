/// Backend proxy configuration.
///
/// Override at build time:
/// `flutter run --dart-define=SPLITMIND_API_BASE_URL=https://api.splitmind.app`
abstract final class ApiConfig {
  static const String baseUrl = String.fromEnvironment('SPLITMIND_API_BASE_URL', defaultValue: 'http://localhost:8787');

  static const Duration requestTimeout = Duration(seconds: 30);
}
