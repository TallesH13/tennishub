import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tennishub/core/theme/app_spacing.dart';
import 'package:tennishub/features/reports/domain/rental_report.dart';
import 'package:tennishub/features/reports/presentation/state/reports_controller.dart';
import 'package:tennishub/features/reports/presentation/state/reports_state.dart';
import 'package:tennishub/features/reports/presentation/widgets/rentals_table.dart';
import 'package:tennishub/features/reports/presentation/widgets/report_totals_view.dart';

/// Chaves para os testes encontrarem os botões da seção de resultado.
abstract final class ReportResultKeys {
  static const Key export = Key('report-export');
  static const Key retry = Key('report-retry');
}

/// Área abaixo do formulário: mostra o que cada estado do relatório pede
/// (ainda não gerado, carregando, erro, vazio ou com resultado).
class ReportResultSection extends ConsumerWidget {
  const ReportResultSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reportsControllerProvider);

    return switch (state.status) {
      ReportStatus.initial => const _InitialView(),
      ReportStatus.loading => const _LoadingView(),
      ReportStatus.failure => _FailureView(
        message: state.errorMessage ?? 'Não foi possível gerar o relatório.',
        onRetry: () => unawaited(
          ref.read(reportsControllerProvider.notifier).generate(state.filter),
        ),
      ),
      ReportStatus.success => _ReportView(
        report: state.report!,
        isExporting: state.isExporting,
        onExport: () => _export(context, ref),
      ),
    };
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final outcome = await ref
        .read(reportsControllerProvider.notifier)
        .exportPdf();
    if (!context.mounted) {
      return;
    }

    final message = switch (outcome) {
      ExportSucceeded(:final fileName) => 'PDF gerado: $fileName',
      ExportFailed(:final message) => message,
      ExportSkipped() => null,
    };
    if (message != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }
}

class _InitialView extends StatelessWidget {
  const _InitialView();

  @override
  Widget build(BuildContext context) {
    return const _MessageCard(
      icon: Icons.bar_chart_outlined,
      message: 'Escolha o período e toque em "Gerar relatório".',
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: AppSpacing.md),
            Text('Gerando o relatório...'),
          ],
        ),
      ),
    );
  }
}

class _FailureView extends StatelessWidget {
  const _FailureView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _MessageCard(
      icon: Icons.error_outline,
      message: message,
      action: FilledButton(
        key: ReportResultKeys.retry,
        onPressed: onRetry,
        child: const Text('Tentar novamente'),
      ),
    );
  }
}

class _ReportView extends StatelessWidget {
  const _ReportView({
    required this.report,
    required this.isExporting,
    required this.onExport,
  });

  final RentalReport report;
  final bool isExporting;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Resultado',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            OutlinedButton.icon(
              key: ReportResultKeys.export,
              onPressed: isExporting ? null : onExport,
              icon: isExporting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Exportar PDF'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        ReportTotalsView(report: report),
        const SizedBox(height: AppSpacing.lg),
        if (report.isEmpty)
          const _MessageCard(
            icon: Icons.event_busy_outlined,
            message: 'Nenhuma locação encontrada no período.',
          )
        else ...[
          Text('Locações', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          RentalsTable(rentals: report.rentals),
        ],
      ],
    );
  }
}

/// Cartão com um ícone, uma mensagem e, se for o caso, uma ação.
class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.icon, required this.message, this.action});

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(message)),
            if (action != null) ...[
              const SizedBox(width: AppSpacing.md),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
