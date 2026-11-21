import 'package:flutter_test/flutter_test.dart';
import 'package:tennishub/core/formatting/text_normalizer.dart';

void main() {
  group('TextNormalizer.removeAccents', () {
    test('troca letras acentuadas pelas equivalentes', () {
      expect(TextNormalizer.removeAccents('locações'), 'locacoes');
      expect(TextNormalizer.removeAccents('Fábio Nogueira'), 'Fabio Nogueira');
      expect(TextNormalizer.removeAccents('ÁÉÍÓÚ Ç Ñ'), 'AEIOU C N');
    });

    test('mantém o que não tem acento', () {
      expect(
        TextNormalizer.removeAccents('Quadra 1 - R\$ 60,00'),
        'Quadra 1 - R\$ 60,00',
      );
    });
  });

  group('TextNormalizer.forSearch', () {
    test('ignora acentos, maiúsculas e espaços nas pontas', () {
      expect(TextNormalizer.forSearch('  FÁBIO  '), 'fabio');
    });
  });
}
