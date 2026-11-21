import 'package:tennishub/features/reports/domain/rental_report.dart';
import 'package:tennishub/features/reports/domain/report_court.dart';
import 'package:tennishub/features/reports/domain/report_file.dart';
import 'package:tennishub/features/reports/domain/report_filter.dart';

/// Erro ao buscar ou exportar o relatório, com uma mensagem que pode ser
/// mostrada ao proprietário.
final class ReportsException implements Exception {
  const ReportsException(this.message);

  final String message;

  @override
  String toString() => 'ReportsException: $message';
}

/// Acesso aos dados do relatório de locações (RF10).
///
/// Hoje a implementação é falsa (em memória). Na integração com a API
/// (issues #20 e #21), entra a implementação HTTP no lugar dela.
abstract interface class ReportsRepository {
  /// Busca as locações realizadas e os totais conforme o [filter].
  ///
  /// Lança [ReportsException] se não for possível gerar o relatório.
  Future<RentalReport> fetchReport(ReportFilter filter);

  /// Gera o mesmo relatório em PDF.
  ///
  /// Lança [ReportsException] se não for possível gerar o arquivo.
  Future<ReportFile> exportPdf(ReportFilter filter);

  /// Quadras disponíveis para filtrar o relatório.
  Future<List<ReportCourt>> listCourts();
}

/// Entrega o arquivo do relatório ao usuário (no navegador, é um download).
abstract interface class ReportFileSaver {
  /// Lança [ReportsException] se o arquivo não puder ser entregue.
  Future<void> save(ReportFile file);
}
