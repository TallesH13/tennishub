import 'package:tennishub/features/reports/domain/rental_report.dart';
import 'package:tennishub/features/reports/domain/report_filter.dart';

/// Em que ponto está a geração do relatório.
enum ReportStatus {
  /// Ainda não foi gerado nenhum relatório.
  initial,

  /// Buscando os dados.
  loading,

  /// Relatório pronto em [ReportsState.report].
  success,

  /// Não foi possível gerar; a mensagem está em [ReportsState.errorMessage].
  failure,
}

/// Estado da tela do relatório de locações.
final class ReportsState {
  const ReportsState({
    required this.filter,
    this.status = ReportStatus.initial,
    this.report,
    this.appliedFilter,
    this.errorMessage,
    this.isExporting = false,
  });

  /// Último filtro enviado para gerar o relatório.
  final ReportFilter filter;

  final ReportStatus status;

  /// Relatório mostrado na tela (só quando [status] é `success`).
  final RentalReport? report;

  /// Filtro com que o [report] foi gerado. A exportação em PDF usa este
  /// filtro, para o PDF ser igual ao que está na tela.
  final ReportFilter? appliedFilter;

  /// Mensagem do erro (só quando [status] é `failure`).
  final String? errorMessage;

  /// `true` enquanto o PDF está sendo gerado e baixado.
  final bool isExporting;

  ReportsState copyWith({
    ReportFilter? filter,
    ReportStatus? status,
    RentalReport? report,
    bool clearReport = false,
    ReportFilter? appliedFilter,
    bool clearAppliedFilter = false,
    String? errorMessage,
    bool clearError = false,
    bool? isExporting,
  }) {
    return ReportsState(
      filter: filter ?? this.filter,
      status: status ?? this.status,
      report: clearReport ? null : report ?? this.report,
      appliedFilter: clearAppliedFilter
          ? null
          : appliedFilter ?? this.appliedFilter,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      isExporting: isExporting ?? this.isExporting,
    );
  }
}

/// Resultado de um pedido de exportação do PDF.
sealed class ExportOutcome {
  const ExportOutcome();
}

/// O PDF foi gerado e entregue ao usuário.
final class ExportSucceeded extends ExportOutcome {
  const ExportSucceeded(this.fileName);

  final String fileName;
}

/// Não foi possível gerar ou entregar o PDF.
final class ExportFailed extends ExportOutcome {
  const ExportFailed(this.message);

  final String message;
}

/// Nada foi feito: não há relatório na tela ou já há uma exportação em curso.
final class ExportSkipped extends ExportOutcome {
  const ExportSkipped();
}
