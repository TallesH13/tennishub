import 'package:flutter_test/flutter_test.dart';
import 'package:tennishub/core/config/app_config.dart';

void main() {
  group('AppConfig.fromUrl', () {
    test('remove a barra final do endereço', () {
      final config = AppConfig.fromUrl('http://localhost:8080/');

      expect(config.apiBaseUrl, 'http://localhost:8080');
    });

    test('mantém o endereço que já está sem barra final', () {
      final config = AppConfig.fromUrl('http://localhost:8080');

      expect(config.apiBaseUrl, 'http://localhost:8080');
    });

    test('ignora espaços em volta do endereço', () {
      final config = AppConfig.fromUrl('  http://localhost:8080/  ');

      expect(config.apiBaseUrl, 'http://localhost:8080');
    });
  });
}
