import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tennishub/features/reports/data/fake_reports_repository.dart';
import 'package:tennishub/features/reports/domain/report_filter.dart';

/// "Hoje" fixo dos testes: 20/11/2026, à tarde.
final DateTime today = DateTime(2026, 11, 20, 15);

FakeReportsRepository newRepository() {
  return FakeReportsRepository(clock: () => today);
}

ReportFilter wholeRange() {
  return ReportFilter(from: DateTime(2026, 9, 1), to: DateTime(2026, 11, 30));
}

void main() {
  group('fetchReport', () {
    test('traz locações de exemplo no período, com totais', () async {
      final report = await newRepository().fetchReport(wholeRange());

      expect(report.isEmpty, isFalse);
      expect(report.totals.count, report.rentals.length);
      expect(report.totals.hours, report.totals.count);
      expect(report.totals.valueCents, isNotNull);
    });

    test('só traz locações que já aconteceram', () async {
      final report = await newRepository().fetchReport(wholeRange());

      expect(report.rentals.every((r) => r.startsAt.isBefore(today)), isTrue);
    });

    test('respeita o período, incluindo o dia final', () async {
      final repository = newRepository();
      final filter = ReportFilter(
        from: DateTime(2026, 11, 10),
        to: DateTime(2026, 11, 12),
      );

      final report = await repository.fetchReport(filter);

      expect(report.isEmpty, isFalse);
      for (final rental in report.rentals) {
        final day = DateTime(
          rental.startsAt.year,
          rental.startsAt.month,
          rental.startsAt.day,
        );
        expect(day.isBefore(DateTime(2026, 11, 10)), isFalse);
        expect(day.isAfter(DateTime(2026, 11, 12)), isFalse);
      }
    });

    test('período sem locações devolve relatório vazio', () async {
      final filter = ReportFilter(
        from: DateTime(2020, 1, 1),
        to: DateTime(2020, 1, 31),
      );

      final report = await newRepository().fetchReport(filter);

      expect(report.isEmpty, isTrue);
      expect(report.totals.count, 0);
      expect(report.byCourt, isEmpty);
    });

    test('filtra por quadra', () async {
      final filter = wholeRange().copyWith(courtId: 'court-3');

      final report = await newRepository().fetchReport(filter);

      expect(report.isEmpty, isFalse);
      expect(report.rentals.every((r) => r.courtId == 'court-3'), isTrue);
      expect(report.byCourt, hasLength(1));
    });

    test(
      'filtra por parte do nome, sem diferenciar acento nem maiúscula',
      () async {
        final filter = wholeRange().copyWith(client: 'FABIO');

        final report = await newRepository().fetchReport(filter);

        expect(report.isEmpty, isFalse);
        expect(
          report.rentals.every((r) => r.clientName.contains('Fábio')),
          isTrue,
        );
      },
    );

    test('filtra por telefone, em qualquer formatação', () async {
      final filter = wholeRange().copyWith(client: '(31) 99999-0002');

      final report = await newRepository().fetchReport(filter);

      expect(report.isEmpty, isFalse);
      expect(
        report.rentals.every((r) => r.clientPhone == '31999990002'),
        isTrue,
      );
    });

    test('combina os filtros: todos precisam valer', () async {
      final base = await newRepository().fetchReport(wholeRange());
      final combined = await newRepository().fetchReport(
        wholeRange().copyWith(courtId: 'court-1', client: 'Ana'),
      );

      expect(combined.totals.count, lessThan(base.totals.count));
      expect(
        combined.rentals.every(
          (r) => r.courtId == 'court-1' && r.clientName.contains('Ana'),
        ),
        isTrue,
      );
    });

    test('a quadra sem valor por hora não soma valor', () async {
      final filter = wholeRange().copyWith(courtId: 'court-4');

      final report = await newRepository().fetchReport(filter);

      expect(report.isEmpty, isFalse);
      expect(report.totals.valueCents, isNull);
    });

    test('devolve sempre os mesmos dados para o mesmo "hoje"', () async {
      final first = await newRepository().fetchReport(wholeRange());
      final second = await newRepository().fetchReport(wholeRange());

      expect(
        [for (final r in first.rentals) r.id],
        [for (final r in second.rentals) r.id],
      );
    });
  });

  group('exportPdf', () {
    test('gera um PDF com nome que traz o período', () async {
      final filter = ReportFilter(
        from: DateTime(2026, 11, 1),
        to: DateTime(2026, 11, 30),
      );

      final file = await newRepository().exportPdf(filter);

      expect(file.fileName, 'relatorio-locacoes-2026-11-01-a-2026-11-30.pdf');
      expect(ascii.decode(file.bytes).startsWith('%PDF-1.4'), isTrue);
    });

    test('o PDF traz o período e os totais do mesmo relatório', () async {
      final filter = wholeRange().copyWith(courtId: 'court-3');
      final repository = newRepository();

      final report = await repository.fetchReport(filter);
      final file = await repository.exportPdf(filter);
      final text = ascii.decode(file.bytes);

      expect(text, contains('Periodo: 01/09/2026 a 30/11/2026'));
      expect(text, contains('Quadra: Quadra Coberta'));
      expect(text, contains('Locacoes: ${report.totals.count}'));
    });
  });

  group('listCourts', () {
    test('devolve as quadras de exemplo', () async {
      final courts = await newRepository().listCourts();

      expect(courts.map((c) => c.id), [
        'court-1',
        'court-2',
        'court-3',
        'court-4',
      ]);
    });
  });

  group('latency', () {
    testWidgets('espera o tempo configurado antes de responder', (
      tester,
    ) async {
      final repository = FakeReportsRepository(
        clock: () => today,
        latency: const Duration(milliseconds: 300),
      );

      var answered = false;
      unawaited(
        repository.fetchReport(wholeRange()).then((_) => answered = true),
      );

      await tester.pump(const Duration(milliseconds: 299));
      expect(answered, isFalse);

      await tester.pump(const Duration(milliseconds: 1));
      expect(answered, isTrue);
    });
  });
}
