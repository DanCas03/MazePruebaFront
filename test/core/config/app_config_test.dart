import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_arrow_maze/core/config/app_config.dart';

void main() {
  test('defaults apiBaseUrl to the Android-emulator host loopback', () {
    // Without --dart-define, the compile-time default applies.
    expect(AppConfig.apiBaseUrl, 'http://10.0.2.2:3000');
  });
}
