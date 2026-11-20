import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tennishub/core/layout/app_page.dart';
import 'package:tennishub/core/router/app_routes.dart';
import 'package:tennishub/core/theme/app_spacing.dart';

/// Página exibida quando o endereço não corresponde a nenhuma rota.
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppPage(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 48),
            const SizedBox(height: AppSpacing.md),
            Text('Página não encontrada', style: textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            const Text('O endereço acessado não existe no TennisHub.'),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () => context.go(AppRoutes.home),
              child: const Text('Voltar ao início'),
            ),
          ],
        ),
      ),
    );
  }
}
