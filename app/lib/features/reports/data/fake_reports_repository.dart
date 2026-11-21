import 'package:tennishub/core/formatting/br_format.dart';
import 'package:tennishub/core/formatting/text_normalizer.dart';
import 'package:tennishub/core/time/clock.dart';
import 'package:tennishub/features/reports/data/simple_pdf.dart';
import 'package:tennishub/features/reports/domain/rental.dart';
import 'package:tennishub/features/reports/domain/rental_report.dart';
import 'package:tennishub/features/reports/domain/report_court.dart';
import 'package:tennishub/features/reports/domain/report_file.dart';
import 'package:tennishub/features/reports/domain/report_filter.dart';
import 'package:tennishub/features/reports/domain/reports_repository.dart';

/// Implementação em memória do [ReportsRepository], com locações de exemplo
/// dos últimos 60 dias. Serve ao desenvolvimento das telas e aos testes até
/// a integração com a API (issues #20 e #21).
///
/// As locações são geradas a partir de "hoje", então sempre existem dados
/// recentes para o relatório; todas já aconteceram.
class FakeReportsRepository implements ReportsRepository {
  FakeReportsRepository({Clock? clock, this.latency = Duration.zero})
    : _clock = clock ?? DateTime.now;

  final Clock _clock;

  /// Espera simulada antes de cada resposta, para ver o estado de carregando.
  final Duration latency;

  static const List<_FakeCourt> _courts = [
    _FakeCourt('court-1', 'Quadra 1', 6000),
    _FakeCourt('court-2', 'Quadra 2', 6000),
    _FakeCourt('court-3', 'Quadra Coberta', 8000),
    _FakeCourt('court-4', 'Quadra de Treino', null),
  ];

  static const List<_FakeClient> _clients = [
    _FakeClient('Ana Paula Souza', '31999990001'),
    _FakeClient('Bruno Henrique Lima', '31999990002'),
    _FakeClient('Carla Mendes Ribeiro', '31999990003'),
    _FakeClient('Diego Alves Pereira', '31999990004'),
    _FakeClient('Elisa Martins Rocha', '31999990005'),
    _FakeClient('Fábio Nogueira Costa', '31999990006'),
  ];

  @override
  Future<RentalReport> fetchReport(ReportFilter filter) async {
    await _wait();
    return _buildReport(filter);
  }

  @override
  Future<ReportFile> exportPdf(ReportFilter filter) async {
    await _wait();
    final report = _buildReport(filter);

    final lines = <String>[
      'Relatório de locações',
      'Período: ${BrFormat.date(filter.from)} a ${BrFormat.date(filter.to)}',
      if (filter.client != null) 'Cliente: ${filter.client}',
      if (filter.courtId != null) 'Quadra: ${_courtName(filter.courtId!)}',
      '',
      'Locações: ${report.totals.count}'
          ' | Horas: ${report.totals.hours}'
          ' | Valor: ${_money(report.totals.valueCents)}',
      '',
      for (final court in report.byCourt)
        '${court.courtName}: ${court.totals.count} locações, '
            '${_money(court.totals.valueCents)}',
      '',
      for (final rental in report.rentals)
        '${BrFormat.dateTime(rental.startsAt)}  ${rental.courtName}  '
            '${rental.clientName}  ${BrFormat.phone(rental.clientPhone)}  '
            '${_money(rental.valueCents)}',
    ];

    return ReportFile(
      fileName: _fileName(filter),
      bytes: buildSimplePdf(lines),
    );
  }

  @override
  Future<List<ReportCourt>> listCourts() async {
    await _wait();
    return [
      for (final court in _courts) ReportCourt(id: court.id, name: court.name),
    ];
  }

  Future<void> _wait() async {
    if (latency > Duration.zero) {
      await Future<void>.delayed(latency);
    }
  }

  RentalReport _buildReport(ReportFilter filter) {
    final from = filter.from;
    final endExclusive = DateTime(
      filter.to.year,
      filter.to.month,
      filter.to.day + 1,
    );

    final matching = _generateRentals().where((rental) {
      final inPeriod =
          !rental.startsAt.isBefore(from) &&
          rental.startsAt.isBefore(endExclusive);
      final sameCourt =
          filter.courtId == null || rental.courtId == filter.courtId;
      return inPeriod && sameCourt && _matchesClient(rental, filter.client);
    });

    return RentalReport.fromRentals(matching.toList());
  }

  /// Nome (sem diferenciar maiúsculas nem acentos) ou telefone, em qualquer
  /// formatação, contendo o texto buscado.
  bool _matchesClient(Rental rental, String? query) {
    if (query == null || query.trim().isEmpty) {
      return true;
    }

    final byName = TextNormalizer.forSearch(rental.clientName)
        .contains(TextNormalizer.forSearch(query));

    final queryDigits = query.replaceAll(RegExp(r'\D'), '');
    final byPhone =
        queryDigits.isNotEmpty && rental.clientPhone.contains(queryDigits);

    return byName || byPhone;
  }

  /// Gera as locações de exemplo dos 60 dias anteriores a hoje, sempre iguais
  /// para o mesmo "hoje".
  List<Rental> _generateRentals() {
    final now = _clock();
    final today = DateTime(now.year, now.month, now.day);
    final rentals = <Rental>[];

    for (var daysAgo = 1; daysAgo <= 60; daysAgo++) {
      final day = DateTime(today.year, today.month, today.day - daysAgo);

      if (daysAgo % 3 != 0) {
        rentals.add(
          _rental(
            id: 'rental-$daysAgo-a',
            day: day,
            hour: 8 + (daysAgo * 3) % 12,
            court: _courts[daysAgo % _courts.length],
            client: _clients[daysAgo % _clients.length],
          ),
        );
      }

      if (daysAgo % 5 == 0) {
        rentals.add(
          _rental(
            id: 'rental-$daysAgo-b',
            day: day,
            hour: 18 + daysAgo % 3,
            court: _courts[(daysAgo + 1) % _courts.length],
            client: _clients[(daysAgo + 2) % _clients.length],
          ),
        );
      }
    }

    return rentals;
  }

  Rental _rental({
    required String id,
    required DateTime day,
    required int hour,
    required _FakeCourt court,
    required _FakeClient client,
  }) {
    return Rental(
      id: id,
      startsAt: DateTime(day.year, day.month, day.day, hour),
      courtId: court.id,
      courtName: court.name,
      clientName: client.name,
      clientPhone: client.phone,
      valueCents: court.hourlyValueCents,
    );
  }

  String _courtName(String courtId) {
    return _courts
        .firstWhere(
          (court) => court.id == courtId,
          orElse: () => _FakeCourt(courtId, courtId, null),
        )
        .name;
  }

  String _money(int? cents) => cents == null ? '-' : BrFormat.money(cents);

  String _fileName(ReportFilter filter) {
    return 'relatorio-locacoes-${_isoDate(filter.from)}'
        '-a-${_isoDate(filter.to)}.pdf';
  }

  String _isoDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

class _FakeCourt {
  const _FakeCourt(this.id, this.name, this.hourlyValueCents);

  final String id;
  final String name;
  final int? hourlyValueCents;
}

class _FakeClient {
  const _FakeClient(this.name, this.phone);

  final String name;
  final String phone;
}
