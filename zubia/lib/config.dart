/// Application configuration.
class Config {
  /// The server URL.
  ///
  /// Can be overridden at compile time using:
  /// `flutter run --dart-define=SERVER_URL=https://your-server-url.com`
  static const String serverUrl = String.fromEnvironment(
    'SERVER_URL',
    defaultValue: 'http://15.204.95.57',
  );
}
