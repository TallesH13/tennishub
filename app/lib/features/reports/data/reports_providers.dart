import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tennishub/core/config/app_config.dart';
import 'package:tennishub/core/network/network_providers.dart';
import 'package:tennishub/core/time/clock.dart';
import 'package:tennishub/features/reports/data/fake_reports_repository.dart';
import 'package:tennishub/features/reports/data/http_reports_repository.dart';
import 'package:tennishub/features/reports/data/report_file_saver_factory.dart';
import 'package:tennishub/features/reports/domain/reports_repository.dart';

/// Repositório do relatório: API real ou implementação falsa (`API_MODE`).
final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return switch (ref.watch(appConfigProvider).apiMode) {
    ApiMode.http => HttpReportsRepository(ref.watch(apiClientProvider)),
    ApiMode.fake => FakeReportsRepository(
      clock: ref.watch(clockProvider),
      latency: const Duration(milliseconds: 400),
    ),
  };
});

/// Entrega o PDF ao usuário (download no navegador).
final reportFileSaverProvider = Provider<ReportFileSaver>(
  (ref) => createReportFileSaver(),
);
