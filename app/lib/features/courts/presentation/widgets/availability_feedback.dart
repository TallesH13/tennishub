import 'package:material_ui/material_ui.dart';
import 'package:tennishub/core/theme/app_spacing.dart';

class AvailabilityLoading extends StatelessWidget {
  const AvailabilityLoading({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Carregando horários...', textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            for (var index = 0; index < 6; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  children: [
                    for (var column = 0; column < 4; column++)
                      Expanded(
                        child: Container(
                          height: 32,
                          margin: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class AvailabilityError extends StatelessWidget {
  const AvailabilityError({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Não foi possível carregar os horários',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Verifique sua conexão e tente novamente.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

class AvailabilityEmpty extends StatelessWidget {
  const AvailabilityEmpty({super.key, required this.onNextDay});

  final VoidCallback? onNextDay;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          children: [
            const Icon(Icons.event_busy_outlined, size: 48),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Nenhum horário livre neste dia',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Selecione outra data para consultar '
              'novos horários.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton(
              onPressed: onNextDay,
              child: const Text('Consultar próximo dia'),
            ),
          ],
        ),
      ),
    );
  }
}
