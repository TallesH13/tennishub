import 'package:tennishub/features/reports/domain/rental.dart';

/// Totais de um conjunto de locações.
final class RentalTotals {
  const RentalTotals({
    required this.count,
    required this.hours,
    required this.valueCents,
  });

  /// Soma dos totais de [rentals]. O valor só é somado quando pelo menos uma
  /// locação tem valor; se nenhuma tem, fica `null` (e não zero).
  factory RentalTotals.fromRentals(Iterable<Rental> rentals) {
    var count = 0;
    var hours = 0;
    int? valueCents;

    for (final rental in rentals) {
      count++;
      hours += rental.hours;
      final value = rental.valueCents;
      if (value != null) {
        valueCents = (valueCents ?? 0) + value;
      }
    }

    return RentalTotals(count: count, hours: hours, valueCents: valueCents);
  }

  /// Quantidade de locações.
  final int count;

  /// Horas locadas.
  final int hours;

  /// Valor total em centavos, ou `null` se nenhuma locação tem valor.
  final int? valueCents;
}

/// Totais de uma quadra no período.
final class CourtTotals {
  const CourtTotals({
    required this.courtId,
    required this.courtName,
    required this.totals,
  });

  final String courtId;
  final String courtName;
  final RentalTotals totals;
}

/// Resultado do relatório de locações: a lista de locações e os totais,
/// gerais e por quadra.
final class RentalReport {
  const RentalReport({
    required this.rentals,
    required this.totals,
    required this.byCourt,
  });

  /// Monta o relatório a partir das locações: ordena por data e hora, soma os
  /// totais gerais e agrupa os totais por quadra (em ordem alfabética).
  factory RentalReport.fromRentals(List<Rental> rentals) {
    final sorted = [...rentals]
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

    final rentalsByCourt = <String, List<Rental>>{};
    for (final rental in sorted) {
      rentalsByCourt.putIfAbsent(rental.courtId, () => []).add(rental);
    }

    final byCourt = [
      for (final group in rentalsByCourt.values)
        CourtTotals(
          courtId: group.first.courtId,
          courtName: group.first.courtName,
          totals: RentalTotals.fromRentals(group),
        ),
    ]..sort((a, b) => a.courtName.compareTo(b.courtName));

    return RentalReport(
      rentals: sorted,
      totals: RentalTotals.fromRentals(sorted),
      byCourt: byCourt,
    );
  }

  /// Locações do período, da mais antiga para a mais recente.
  final List<Rental> rentals;

  final RentalTotals totals;

  /// Totais por quadra, só das quadras que tiveram locação.
  final List<CourtTotals> byCourt;

  bool get isEmpty => rentals.isEmpty;
}
