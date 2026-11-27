import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tennishub/core/router/app_routes.dart';
import 'package:tennishub/core/session/owner_session.dart';
import 'package:tennishub/core/theme/app_spacing.dart';

/// Início do painel do proprietário (rota `/admin`).
class AdminHomePage extends ConsumerWidget {
  const AdminHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final firstName = ref
        .watch(sessionStoreProvider)
        ?.owner
        .name
        .split(' ')
        .first;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            firstName == null ? 'Painel do proprietário' : 'Olá, $firstName',
            style: textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
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
            child: ListTile(
              leading: Icon(Icons.event_outlined),
              title: Text('Agendamentos, quadras e horários'),
              subtitle: Text('Em construção.'),
            ),
          ),
        ],
      ),
    );
  }
}
