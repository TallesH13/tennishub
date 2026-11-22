import 'package:flutter_test/flutter_test.dart';
import 'package:tennishub/core/formatting/br_format.dart';

void main() {
  group('BrFormat.date', () {
    test('completa dia e mês com zero à esquerda', () {
      expect(BrFormat.date(DateTime(2026, 3, 5)), '05/03/2026');
    });

    test('mantém dia e mês com dois dígitos', () {
      expect(BrFormat.date(DateTime(2026, 11, 20)), '20/11/2026');
    });
  });

  group('BrFormat.dateTime', () {
    test('junta data e hora', () {
      expect(
        BrFormat.dateTime(DateTime(2026, 11, 20, 8, 5)),
        '20/11/2026 08:05',
      );
    });
  });

  group('BrFormat.parseDate', () {
    test('lê uma data válida', () {
      expect(BrFormat.parseDate('20/11/2026'), DateTime(2026, 11, 20));
    });

    test('ignora espaços em volta', () {
      expect(BrFormat.parseDate('  01/02/2026 '), DateTime(2026, 2, 1));
    });

    test('rejeita texto incompleto', () {
      expect(BrFormat.parseDate('20/11/26'), isNull);
      expect(BrFormat.parseDate('20/11'), isNull);
      expect(BrFormat.parseDate(''), isNull);
    });

    test('rejeita data que não existe', () {
      expect(BrFormat.parseDate('31/02/2026'), isNull);
      expect(BrFormat.parseDate('00/10/2026'), isNull);
      expect(BrFormat.parseDate('10/13/2026'), isNull);
    });

    test('aceita 29/02 só em ano bissexto', () {
      expect(BrFormat.parseDate('29/02/2028'), DateTime(2028, 2, 29));
      expect(BrFormat.parseDate('29/02/2026'), isNull);
    });

    test('rejeita formato diferente de dd/mm/aaaa', () {
      expect(BrFormat.parseDate('2026-11-20'), isNull);
      expect(BrFormat.parseDate('20-11-2026'), isNull);
    });
  });

  group('BrFormat.money', () {
    test('mostra centavos com vírgula', () {
      expect(BrFormat.money(6050), r'R$ 60,50');
    });

    test('completa centavos com zero', () {
      expect(BrFormat.money(6005), r'R$ 60,05');
      expect(BrFormat.money(5), r'R$ 0,05');
      expect(BrFormat.money(0), r'R$ 0,00');
    });

    test('separa milhares com ponto', () {
      expect(BrFormat.money(123450), r'R$ 1.234,50');
      expect(BrFormat.money(100000000), r'R$ 1.000.000,00');
      expect(BrFormat.money(99900), r'R$ 999,00');
    });
  });

  group('BrFormat.phone', () {
    test('formata celular com 11 dígitos', () {
      expect(BrFormat.phone('31999990000'), '(31) 99999-0000');
    });

    test('formata fixo com 10 dígitos', () {
      expect(BrFormat.phone('3133334444'), '(31) 3333-4444');
    });

    test('devolve como veio quando não tem 10 ou 11 dígitos', () {
      expect(BrFormat.phone('12345'), '12345');
    });
  });
}
