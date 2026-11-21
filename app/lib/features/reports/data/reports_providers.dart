import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tennishub/core/time/clock.dart';
import 'package:tennishub/features/reports/data/fake_reports_repository.dart';
import 'package:tennishub/features/reports/data/report_file_saver_factory.dart';
import 'package:tennishub/features/reports/domain/reports_repository.dart';

/// Repositório do relatório.
///
/// Por enquanto devolve a implementação falsa. Na integração com a API
/// (issues #20 e #21), troque por uma implementação HTTP aqui.
final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return FakeReportsRepository(
    clock: ref.watch(clockProvider),
    latency: const Duration(milliseconds: 400),
  );
});

/// Entrega o PDF ao usuário (download no navegador).
final reportFileSaverProvider = Provider<ReportFileSaver>(
  (ref) => createReportFileSaver(),
);
