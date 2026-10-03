import 'package:flutter_test/flutter_test.dart';

import 'package:banta_rider_app/core/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('stores the configured backend base url', () {
      const config = AppConfig(
        baseUrl: 'https://api.bantai.test',
        appName: 'BANTAI',
      );

      expect(config.baseUrl, 'https://api.bantai.test');
      expect(config.appName, 'BANTAI');
      expect(config.isProduction, isFalse);
    });
  });
}
