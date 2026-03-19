import 'package:flutter_test/flutter_test.dart';
import 'package:zubia/config.dart';

void main() {
  test('Config.serverUrl defaults to http://15.204.95.57', () {
    // Verify the default value is correct when no environment variable is provided.
    // Note: If this test is run with --dart-define=SERVER_URL=..., it might fail if the value differs.
    // We assume standard `flutter test` execution uses defaults.
    if (const String.fromEnvironment('SERVER_URL').isEmpty) {
      expect(Config.serverUrl, 'http://15.204.95.57');
    } else {
      expect(Config.serverUrl, const String.fromEnvironment('SERVER_URL'));
    }
  });
}
