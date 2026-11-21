import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:tennishub/features/reports/data/http_reports_repository.dart';
import 'package:tennishub/features/reports/domain/report_filter.dart';
import 'package:tennishub/features/reports/domain/reports_repository.dart';

import '../../../support/api_samples.dart';
import '../../../support/api_test_support.dart';

void main() {
  final filter = ReportFilter(
    from: DateTime(2026, 11),
    to: DateTime(2026, 11, 30),
    courtId: '1',
    client: ' Ana ',
  );

  test('busca as locações com os filtros e calcula os totais', () async {
    final api = FakeApi(
      (_) async => jsonResponse(rentalsResponse),
      token: sampleToken,
    );

    final report = await HttpReportsRepository(api.client).fetchReport(filter);

    expect(api.lastRequest.url.path, '/api/owner/reports/rentals');
    expect(api.lastRequest.url.queryParameters, {
      'from': '2026-11-01',
      'to': '2026-11-30',
      'courtId': '1',
      'client': 'Ana',
    });
    expect(report.rentals, hasLength(2));
    expect(report.totals.count, 2);
    expect(
      report.rentals.map((rental) => rental.clientName),
      containsAll(['Ana Paula Ribeiro', 'Rafael Couto']),
    );
  });

  test('exporta o PDF gerado pela API', () async {
    final api = FakeApi(
      (_) async => http.Response.bytes([37, 80, 68, 70], 200),
      token: sampleToken,
    );

    final file = await HttpReportsRepository(api.client).exportPdf(filter);

    expect(api.lastRequest.url.path, '/api/owner/reports/rentals.pdf');
    expect(file.fileName, 'relatorio-locacoes-2026-11-01-a-2026-11-30.pdf');
    expect(file.bytes, [37, 80, 68, 70]);
  });

  test(
    'erros da API viram ReportsException com a mensagem para a tela',
    () async {
      final api = FakeApi(
        (_) async => jsonResponse(sessionExpiredError, 401),
        token: sampleToken,
      );

      await expectLater(
        HttpReportsRepository(api.client).fetchReport(filter),
        throwsA(
          isA<ReportsException>().having(
            (e) => e.message,
            'message',
            'Sessão expirada por inatividade. Faça login novamente.',
          ),
        ),
      );
      expect(api.unauthorizedCalls, 1);
    },
  );

  test('lista as quadras para o filtro', () async {
    final api = FakeApi(
      (_) async => jsonResponse(courtsResponse),
      token: sampleToken,
    );

    final courts = await HttpReportsRepository(api.client).listCourts();

    expect(api.lastRequest.url.path, '/api/owner/courts');
    expect(courts.map((court) => court.name), ['Quadra 1', 'Quadra 4']);
  });
}
