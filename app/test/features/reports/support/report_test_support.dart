import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tennishub/app.dart';
import 'package:tennishub/core/router/app_router.dart';
import 'package:tennishub/core/router/app_routes.dart';
import 'package:tennishub/core/time/clock.dart';
import 'package:tennishub/features/reports/data/reports_providers.dart';
import 'package:tennishub/features/reports/domain/rental.dart';
import 'package:tennishub/features/reports/domain/rental_report.dart';
import 'package:tennishub/features/reports/domain/report_court.dart';
import 'package:tennishub/features/reports/domain/report_file.dart';
import 'package:tennishub/features/reports/domain/report_filter.dart';
import 'package:tennishub/features/reports/domain/reports_repository.dart';

/// "Hoje" fixo dos testes de tela: 20/11/2026, à tarde.
final DateTime testToday = DateTime(2026, 11, 20, 15);

/// Quadras de exemplo dos testes.
const List<ReportCourt> sampleCourts = [
  ReportCourt(id: 'court-1', name: 'Quadra 1'),
  ReportCourt(id: 'court-3', name: 'Quadra Coberta'),
  ReportCourt(id: 'court-4', name: 'Quadra de Treino'),
];

/// Três locações de exemplo, com valores conhecidos:
/// 3 locações, 3 horas, R$ 140,00 (a Quadra de Treino não tem valor).
List<Rental> sampleRentals() {
  return [
    Rental(
      id: 'r1',
      startsAt: DateTime(2026, 11, 3, 8),
      courtId: 'court-1',
      courtName: 'Quadra 1',
      clientName: 'Ana Paula Souza',
      clientPhone: '31999990001',
      valueCents: 6000,
    ),
    Rental(
      id: 'r2',
      startsAt: DateTime(2026, 11, 5, 19),
      courtId: 'court-3',
      courtName: 'Quadra Coberta',
      clientName: 'Bruno Henrique Lima',
      clientPhone: '31999990002',
      valueCents: 8000,
    ),
    Rental(
      id: 'r3',
      startsAt: DateTime(2026, 11, 10, 10),
      courtId: 'court-4',
      courtName: 'Quadra de Treino',
      clientName: 'Carla Mendes Ribeiro',
      clientPhone: '31999990003',
    ),
  ];
}

/// Arquivo de PDF de exemplo dos testes.
ReportFile sampleReportFile() {
  return ReportFile(
    fileName: 'relatorio-teste.pdf',
    bytes: Uint8List.fromList([1, 2, 3]),
  );
}

/// Repositório controlado pelo teste: guarda as chamadas recebidas e deixa
/// o teste decidir o que responder.
class StubReportsRepository implements ReportsRepository {
  StubReportsRepository({List<Rental>? rentals})
    : rentals = rentals ?? sampleRentals();

  final List<Rental> rentals;

  /// Filtros recebidos em [fetchReport], na ordem.
  final List<ReportFilter> fetchCalls = [];

  /// Filtros recebidos em [exportPdf], na ordem.
  final List<ReportFilter> exportCalls = [];

  /// Se informado, responde no lugar do padrão (por exemplo, para falhar ou
  /// para demorar).
  Future<RentalReport> Function(ReportFilter filter)? fetchHandler;
  Future<ReportFile> Function(ReportFilter filter)? exportHandler;

  @override
  Future<RentalReport> fetchReport(ReportFilter filter) {
    fetchCalls.add(filter);
    final handler = fetchHandler;
    if (handler != null) {
      return handler(filter);
    }
    return Future.value(RentalReport.fromRentals(rentals));
  }

  @override
  Future<ReportFile> exportPdf(ReportFilter filter) {
    exportCalls.add(filter);
    final handler = exportHandler;
    if (handler != null) {
      return handler(filter);
    }
    return Future.value(sampleReportFile());
  }

  @override
  Future<List<ReportCourt>> listCourts() => Future.value(sampleCourts);
}

/// Salvador de arquivo dos testes: guarda o que recebeu em vez de baixar.
class RecordingReportFileSaver implements ReportFileSaver {
  final List<ReportFile> saved = [];

  /// Se informado, é lançado em vez de guardar o arquivo.
  Exception? error;

  @override
  Future<void> save(ReportFile file) async {
    final failure = error;
    if (failure != null) {
      throw failure;
    }
    saved.add(file);
  }
}

/// Overrides que trocam os dados reais por [repository] e [saver] e fixam
/// o "hoje" em [testToday].
List<Override> reportOverrides({
  required StubReportsRepository repository,
  RecordingReportFileSaver? saver,
}) {
  return [
    reportsRepositoryProvider.overrideWithValue(repository),
    reportFileSaverProvider.overrideWithValue(
      saver ?? RecordingReportFileSaver(),
    ),
    clockProvider.overrideWithValue(() => testToday),
  ];
}

/// Abre o app inteiro em [location], com o repositório e o salvador falsos,
/// numa janela de desktop (o relatório tem tabelas largas).
Future<void> pumpReportsApp(
  WidgetTester tester, {
  required StubReportsRepository repository,
  RecordingReportFileSaver? saver,
  String location = AppRoutes.adminReports,
}) async {
  tester.view.physicalSize = const Size(1400, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  // O relatório é do painel: os testes já começam com o proprietário logado.
  final router = createAppRouter(
    initialLocation: location,
    isLoggedIn: () => true,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appRouterProvider.overrideWithValue(router),
        ...reportOverrides(repository: repository, saver: saver),
      ],
      child: const TennisHubApp(),
    ),
  );
  await tester.pumpAndSettle();
}
