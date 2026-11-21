import 'package:flutter_test/flutter_test.dart';
import 'package:tennishub/features/reports/domain/report_filter.dart';

void main() {
  group('ReportFilter.periodError', () {
    test('período com início igual ao fim é válido', () {
      final filter = ReportFilter(
        from: DateTime(2026, 11, 10),
        to: DateTime(2026, 11, 10),
      );

      expect(filter.periodError, isNull);
    });

    test('período com início antes do fim é válido', () {
      final filter = ReportFilter(
        from: DateTime(2026, 11, 1),
        to: DateTime(2026, 11, 30),
      );

      expect(filter.periodError, isNull);
    });

    test('fim antes do início é inválido', () {
      final filter = ReportFilter(
        from: DateTime(2026, 11, 10),
        to: DateTime(2026, 11, 9),
      );

      expect(filter.periodError, ReportPeriodError.endBeforeStart);
    });

    test('período de exatamente 1 ano ainda é válido', () {
      final filter = ReportFilter(
        from: DateTime(2025, 11, 20),
        to: DateTime(2026, 11, 20),
      );

      expect(filter.periodError, isNull);
    });

    test('período maior que 1 ano é inválido', () {
      final filter = ReportFilter(
        from: DateTime(2025, 11, 20),
        to: DateTime(2026, 11, 21),
      );

      expect(filter.periodError, ReportPeriodError.tooLong);
    });
  });

  group('atalhos de mês', () {
    test('thisMonth vai do primeiro ao último dia do mês', () {
      final filter = ReportFilter.thisMonth(DateTime(2026, 11, 20, 15, 30));

      expect(filter.from, DateTime(2026, 11, 1));
      expect(filter.to, DateTime(2026, 11, 30));
      expect(filter.periodError, isNull);
    });

    test('thisMonth respeita meses com 28, 29 e 31 dias', () {
      expect(ReportFilter.thisMonth(DateTime(2026, 2, 10)).to.day, 28);
      expect(ReportFilter.thisMonth(DateTime(2028, 2, 10)).to.day, 29);
      expect(ReportFilter.thisMonth(DateTime(2026, 12, 10)).to.day, 31);
    });

    test('lastMonth vai do primeiro ao último dia do mês anterior', () {
      final filter = ReportFilter.lastMonth(DateTime(2026, 11, 20));

      expect(filter.from, DateTime(2026, 10, 1));
      expect(filter.to, DateTime(2026, 10, 31));
    });

    test('lastMonth em janeiro volta para dezembro do ano anterior', () {
      final filter = ReportFilter.lastMonth(DateTime(2026, 1, 15));

      expect(filter.from, DateTime(2025, 12, 1));
      expect(filter.to, DateTime(2025, 12, 31));
    });
  });

  group('copyWith', () {
    final base = ReportFilter(
      from: DateTime(2026, 11, 1),
      to: DateTime(2026, 11, 30),
      client: 'Ana',
      courtId: 'court-1',
    );

    test('troca só o que foi informado', () {
      final copy = base.copyWith(client: 'Bruno');

      expect(copy.client, 'Bruno');
      expect(copy.courtId, 'court-1');
      expect(copy.from, base.from);
    });

    test('clearClient e clearCourt voltam para "todos"', () {
      final copy = base.copyWith(clearClient: true, clearCourt: true);

      expect(copy.client, isNull);
      expect(copy.courtId, isNull);
    });
  });

  group('igualdade', () {
    test('filtros com os mesmos valores são iguais', () {
      final a = ReportFilter(
        from: DateTime(2026, 11, 1),
        to: DateTime(2026, 11, 30),
        client: 'Ana',
      );
      final b = ReportFilter(
        from: DateTime(2026, 11, 1),
        to: DateTime(2026, 11, 30),
        client: 'Ana',
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('filtros com valores diferentes não são iguais', () {
      final a = ReportFilter(
        from: DateTime(2026, 11, 1),
        to: DateTime(2026, 11, 30),
      );
      final b = a.copyWith(courtId: 'court-2');

      expect(a, isNot(b));
    });
  });
}
