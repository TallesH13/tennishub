import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tennishub/core/layout/app_page.dart';
import 'package:tennishub/core/router/app_routes.dart';
import 'package:tennishub/core/theme/app_spacing.dart';
import 'package:tennishub/features/reports/presentation/widgets/report_filter_form.dart';
import 'package:tennishub/features/reports/presentation/widgets/report_result_section.dart';

/// Relatório de locações do proprietário (rota `/admin/relatorios`).
///
/// O proprietário escolhe o período (e, se quiser, cliente e quadra), vê as
/// locações realizadas com os clientes identificados e os totais, e pode
/// baixar o mesmo relatório em PDF.
class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppPage(
      actions: [
        TextButton.icon(
          onPressed: () => context.go(AppRoutes.admin),
          icon: const Icon(Icons.arrow_back),
          label: const Text('Painel do proprietário'),
        ),
      ],
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Relatório de locações', style: textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Locações realizadas em um período, com os clientes '
              'identificados.',
            ),
            const SizedBox(height: AppSpacing.lg),
            const ReportFilterForm(),
            const SizedBox(height: AppSpacing.lg),
            const ReportResultSection(),
          ],
        ),
      ),
    );
  }
}
