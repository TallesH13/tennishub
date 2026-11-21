import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tennishub/core/layout/app_page.dart';
import 'package:tennishub/core/router/app_routes.dart';
import 'package:tennishub/core/theme/app_spacing.dart';

/// Página inicial do painel do proprietário (rota `/admin`).
///
/// Por enquanto é um placeholder: o login e as rotas protegidas entram
/// na issue #25, e as telas de gestão nas issues #26 a #29.
class AdminHomePage extends StatelessWidget {
  const AdminHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppPage(
      actions: [
        TextButton.icon(
          onPressed: () => context.go(AppRoutes.home),
          icon: const Icon(Icons.home_outlined),
          label: const Text('Área pública'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Painel do proprietário', style: textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.sm),
          const Text('Gestão de quadras, horários, agendamentos e relatórios.'),
          const SizedBox(height: AppSpacing.lg),
          Card(
            child: ListTile(
              leading: const Icon(Icons.bar_chart_outlined),
              title: const Text('Relatório de locações'),
              subtitle: const Text(
                'Locações realizadas por período, com os clientes.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(AppRoutes.adminReports),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Icon(Icons.admin_panel_settings_outlined),
                  SizedBox(width: AppSpacing.md),
                  Expanded(child: Text('Em construção: login e painel.')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
