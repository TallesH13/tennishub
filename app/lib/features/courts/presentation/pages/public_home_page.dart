import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tennishub/core/layout/app_page.dart';
import 'package:tennishub/core/router/app_routes.dart';
import 'package:tennishub/core/theme/app_spacing.dart';
import 'package:tennishub/features/courts/presentation/state/availability_controller.dart';
import 'package:tennishub/features/courts/presentation/widgets/booking_steps.dart';
import 'package:tennishub/features/courts/presentation/widgets/date_selector.dart';

/// Página pública de consulta de quadras e horários.
class PublicHomePage extends ConsumerStatefulWidget {
  const PublicHomePage({super.key});

  @override
  ConsumerState<PublicHomePage> createState() => _PublicHomePageState();
}

class _PublicHomePageState extends ConsumerState<PublicHomePage> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      ref.read(availabilityControllerProvider.notifier).loadAvailability();
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isWideScreen = MediaQuery.sizeOf(context).width >= 1000;

    final availabilityState = ref.watch(availabilityControllerProvider);

    final controller = ref.read(availabilityControllerProvider.notifier);

    return AppPage(
      actions: [
        if (isWideScreen) ...[
          TextButton(
            onPressed: () => context.go(AppRoutes.home),
            child: const Text('Horários'),
          ),
          const TextButton(onPressed: null, child: Text('Minha reserva')),
        ],
        TextButton.icon(
          onPressed: () => context.go(AppRoutes.admin),
          icon: const Icon(Icons.lock_outline),
          label: const Text('Área do proprietário'),
        ),
      ],
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Reserve uma quadra', style: textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Escolha o dia e um horário livre. '
              'Não é preciso criar conta.',
            ),
            const SizedBox(height: AppSpacing.xl),
            const BookingSteps(),
            const SizedBox(height: AppSpacing.xl),
            DateSelector(
              today: controller.today,
              lastAllowedDate: controller.lastAllowedDate,
              selectedDate: availabilityState.selectedDate,
              onDateSelected: controller.selectDate,
            ),
            const SizedBox(height: AppSpacing.lg),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(
                  child: Text('A grade de horários será exibida aqui.'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
