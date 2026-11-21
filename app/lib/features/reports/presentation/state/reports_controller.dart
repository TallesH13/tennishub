import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tennishub/core/time/clock.dart';
import 'package:tennishub/features/reports/data/reports_providers.dart';
import 'package:tennishub/features/reports/domain/report_court.dart';
import 'package:tennishub/features/reports/domain/report_filter.dart';
import 'package:tennishub/features/reports/domain/reports_repository.dart';
import 'package:tennishub/features/reports/presentation/state/reports_state.dart';

/// Gera o relatório e exporta o PDF. A tela só lê o estado e chama estes
/// métodos; o acesso aos dados fica no [ReportsRepository].
class ReportsController extends Notifier<ReportsState> {
  static const String _generateErrorMessage =
      'Não foi possível gerar o relatório. Tente novamente.';
  static const String _exportErrorMessage =
      'Não foi possível exportar o PDF. Tente novamente.';

  /// Número do último pedido de relatório, para ignorar respostas antigas
  /// quando o usuário gera de novo antes da anterior chegar.
  int _lastRequest = 0;

  @override
  ReportsState build() {
    final today = ref.read(clockProvider)();
    return ReportsState(filter: ReportFilter.thisMonth(today));
  }

  /// Busca o relatório do [filter]. Ignora filtros com período inválido; a
  /// tela já valida antes de chamar.
  Future<void> generate(ReportFilter filter) async {
    if (filter.periodError != null) {
      return;
    }

    final request = ++_lastRequest;
    state = state.copyWith(
      filter: filter,
      status: ReportStatus.loading,
      clearError: true,
    );

    try {
      final report = await ref
          .read(reportsRepositoryProvider)
          .fetchReport(filter);
      if (!ref.mounted || request != _lastRequest) {
        return;
      }
      state = state.copyWith(
        status: ReportStatus.success,
        report: report,
        appliedFilter: filter,
        clearError: true,
      );
    } on Exception catch (error) {
      if (!ref.mounted || request != _lastRequest) {
        return;
      }
      state = state.copyWith(
        status: ReportStatus.failure,
        clearReport: true,
        clearAppliedFilter: true,
        errorMessage: _messageOf(error, _generateErrorMessage),
      );
    }
  }

  /// Gera o PDF do relatório que está na tela e o entrega ao usuário.
  Future<ExportOutcome> exportPdf() async {
    final filter = state.appliedFilter;
    if (filter == null || state.isExporting) {
      return const ExportSkipped();
    }

    state = state.copyWith(isExporting: true);
    try {
      final file = await ref.read(reportsRepositoryProvider).exportPdf(filter);
      await ref.read(reportFileSaverProvider).save(file);
      return ExportSucceeded(file.fileName);
    } on Exception catch (error) {
      return ExportFailed(_messageOf(error, _exportErrorMessage));
    } finally {
      if (ref.mounted) {
        state = state.copyWith(isExporting: false);
      }
    }
  }

  String _messageOf(Exception error, String fallback) {
    return error is ReportsException ? error.message : fallback;
  }
}

final reportsControllerProvider =
    NotifierProvider.autoDispose<ReportsController, ReportsState>(
      ReportsController.new,
    );

/// Quadras para o filtro do relatório.
final reportCourtsProvider = FutureProvider.autoDispose<List<ReportCourt>>(
  (ref) => ref.watch(reportsRepositoryProvider).listCourts(),
);
