import 'package:tennishub/core/network/api_client.dart';
import 'package:tennishub/core/network/api_exception.dart';
import 'package:tennishub/core/network/json_reader.dart';
import 'package:tennishub/features/reports/domain/rental.dart';
import 'package:tennishub/features/reports/domain/rental_report.dart';
import 'package:tennishub/features/reports/domain/report_court.dart';
import 'package:tennishub/features/reports/domain/report_file.dart';
import 'package:tennishub/features/reports/domain/report_filter.dart';
import 'package:tennishub/features/reports/domain/reports_repository.dart';

/// [ReportsRepository] ligado à API. Contrato em `docs/api.md`.
///
/// Os erros da API viram [ReportsException], que a tela do relatório já
/// sabe mostrar. Um 401 também limpa a sessão (feito pelo [ApiClient]).
class HttpReportsRepository implements ReportsRepository {
  HttpReportsRepository(this._api);

  final ApiClient _api;

  @override
  Future<RentalReport> fetchReport(ReportFilter filter) {
    return _guard(() async {
      final data = await _api.get(
        '/owner/reports/rentals',
        query: _query(filter),
      );
      return parseResponse(() {
        final rentals = [
          for (final item in asJsonMap(data).readList('rentals')) _rental(item),
        ];
        return RentalReport.fromRentals(rentals);
      });
    });
  }

  @override
  Future<ReportFile> exportPdf(ReportFilter filter) {
    return _guard(() async {
      final bytes = await _api.getBytes(
        '/owner/reports/rentals.pdf',
        query: _query(filter),
      );
      final name =
          'relatorio-locacoes-${formatApiDate(filter.from)}-a-${formatApiDate(filter.to)}.pdf';
      return ReportFile(fileName: name, bytes: bytes);
    });
  }

  @override
  Future<List<ReportCourt>> listCourts() {
    return _guard(() async {
      final data = await _api.get('/owner/courts');
      return parseResponse(
        () => [
          for (final court in asJsonMap(data).readList('courts'))
            ReportCourt(id: court.readId('id'), name: court.readString('name')),
        ],
      );
    });
  }

  static Map<String, String?> _query(ReportFilter filter) => {
    'from': formatApiDate(filter.from),
    'to': formatApiDate(filter.to),
    'courtId': filter.courtId,
    'client': filter.client?.trim(),
  };

  static Rental _rental(JsonMap json) {
    return Rental(
      id: json.readId('id'),
      startsAt: json.readDateTime('startsAt'),
      courtId: json.readId('courtId'),
      courtName: json.readString('courtName'),
      clientName: json.readString('clientName'),
      clientPhone: json.readString('clientPhone'),
      valueCents: json.readOptionalInt('valueCents'),
    );
  }

  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on ApiException catch (error) {
      throw ReportsException(error.message);
    }
  }
}
