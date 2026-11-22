import 'package:tennishub/features/reports/domain/report_file.dart';
import 'package:tennishub/features/reports/domain/reports_repository.dart';

/// Cria o [ReportFileSaver] da plataforma. Fora do navegador (como nos
/// testes) não há onde baixar o arquivo.
ReportFileSaver createReportFileSaver() => const _UnsupportedReportFileSaver();

final class _UnsupportedReportFileSaver implements ReportFileSaver {
  const _UnsupportedReportFileSaver();

  @override
  Future<void> save(ReportFile file) {
    throw const ReportsException(
      'Exportar o PDF só está disponível no navegador.',
    );
  }
}
