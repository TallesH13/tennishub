import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tennishub/core/layout/app_page.dart';
import 'package:tennishub/core/router/app_routes.dart';
import 'package:tennishub/core/theme/app_spacing.dart';

/// Página inicial da área pública (rota `/`), aberta sem login.
///
/// Por enquanto é um placeholder: a consulta de quadras e horários
/// entra aqui na issue #22.
class PublicHomePage extends StatelessWidget {
  const PublicHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppPage(
      actions: [
        TextButton.icon(
          onPressed: () => context.go(AppRoutes.admin),
          icon: const Icon(Icons.lock_outline),
          label: const Text('Área do proprietário'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Agende sua quadra', style: textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Consulte as quadras e os horários livres e reserve em poucos '
            'passos, sem criar conta.',
          ),
          const SizedBox(height: AppSpacing.lg),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Icon(Icons.construction),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Em construção: consulta de quadras e horários.',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
