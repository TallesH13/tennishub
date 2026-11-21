import 'package:flutter_test/flutter_test.dart';
import 'package:tennishub/features/reports/domain/rental.dart';
import 'package:tennishub/features/reports/domain/rental_report.dart';

Rental rental({
  required String id,
  required DateTime startsAt,
  String courtId = 'court-1',
  String courtName = 'Quadra 1',
  int? valueCents = 6000,
}) {
  return Rental(
    id: id,
    startsAt: startsAt,
    courtId: courtId,
    courtName: courtName,
    clientName: 'Ana Paula Souza',
    clientPhone: '31999990001',
    valueCents: valueCents,
  );
}

void main() {
  group('RentalTotals.fromRentals', () {
    test('sem locações, tudo zerado e sem valor', () {
      final totals = RentalTotals.fromRentals(const []);

      expect(totals.count, 0);
      expect(totals.hours, 0);
      expect(totals.valueCents, isNull);
    });

    test('soma quantidade, horas e valor', () {
      final totals = RentalTotals.fromRentals([
        rental(id: '1', startsAt: DateTime(2026, 11, 1, 8)),
        rental(id: '2', startsAt: DateTime(2026, 11, 2, 9), valueCents: 8000),
      ]);

      expect(totals.count, 2);
      expect(totals.hours, 2);
      expect(totals.valueCents, 14000);
    });

    test('cada locação vale 1 hora', () {
      expect(rental(id: '1', startsAt: DateTime(2026, 11, 1, 8)).hours, 1);
    });

    test('soma só as locações que têm valor', () {
      final totals = RentalTotals.fromRentals([
        rental(id: '1', startsAt: DateTime(2026, 11, 1, 8)),
        rental(id: '2', startsAt: DateTime(2026, 11, 2, 9), valueCents: null),
      ]);

      expect(totals.count, 2);
      expect(totals.valueCents, 6000);
    });

    test('se nenhuma locação tem valor, o total fica sem valor', () {
      final totals = RentalTotals.fromRentals([
        rental(id: '1', startsAt: DateTime(2026, 11, 1, 8), valueCents: null),
      ]);

      expect(totals.count, 1);
      expect(totals.valueCents, isNull);
    });
  });

  group('RentalReport.fromRentals', () {
    test('ordena as locações da mais antiga para a mais recente', () {
      final report = RentalReport.fromRentals([
        rental(id: 'c', startsAt: DateTime(2026, 11, 3, 10)),
        rental(id: 'a', startsAt: DateTime(2026, 11, 1, 8)),
        rental(id: 'b', startsAt: DateTime(2026, 11, 1, 9)),
      ]);

      expect([for (final r in report.rentals) r.id], ['a', 'b', 'c']);
    });

    test('não altera a lista recebida', () {
      final original = [
        rental(id: 'b', startsAt: DateTime(2026, 11, 2, 8)),
        rental(id: 'a', startsAt: DateTime(2026, 11, 1, 8)),
      ];

      RentalReport.fromRentals(original);

      expect(original.first.id, 'b');
    });

    test('agrupa os totais por quadra, em ordem alfabética', () {
      final report = RentalReport.fromRentals([
        rental(id: '1', startsAt: DateTime(2026, 11, 1, 8)),
        rental(
          id: '2',
          startsAt: DateTime(2026, 11, 1, 9),
          courtId: 'court-3',
          courtName: 'Quadra Coberta',
          valueCents: 8000,
        ),
        rental(id: '3', startsAt: DateTime(2026, 11, 2, 8)),
      ]);

      expect(
        [for (final c in report.byCourt) c.courtName],
        ['Quadra 1', 'Quadra Coberta'],
      );
      expect(report.byCourt.first.totals.count, 2);
      expect(report.byCourt.first.totals.valueCents, 12000);
      expect(report.byCourt.last.totals.count, 1);
      expect(report.byCourt.last.totals.valueCents, 8000);
    });

    test('os totais gerais batem com a soma das quadras', () {
      final report = RentalReport.fromRentals([
        rental(id: '1', startsAt: DateTime(2026, 11, 1, 8)),
        rental(
          id: '2',
          startsAt: DateTime(2026, 11, 1, 9),
          courtId: 'court-3',
          courtName: 'Quadra Coberta',
          valueCents: 8000,
        ),
      ]);

      final countByCourt = report.byCourt.fold<int>(
        0,
        (sum, court) => sum + court.totals.count,
      );
      expect(report.totals.count, countByCourt);
      expect(report.totals.valueCents, 14000);
    });

    test('sem locações, o relatório fica vazio com totais zerados', () {
      final report = RentalReport.fromRentals(const []);

      expect(report.isEmpty, isTrue);
      expect(report.totals.count, 0);
      expect(report.totals.hours, 0);
      expect(report.byCourt, isEmpty);
    });
  });
}
