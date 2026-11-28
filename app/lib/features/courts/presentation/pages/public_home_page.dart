import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tennishub/core/layout/app_page.dart';
import 'package:tennishub/core/router/app_routes.dart';
import 'package:tennishub/core/theme/app_spacing.dart';
import 'package:tennishub/features/courts/domain/availability.dart';
import 'package:tennishub/features/courts/presentation/state/availability_controller.dart';
import 'package:tennishub/features/courts/presentation/state/availability_state.dart';
import 'package:tennishub/features/courts/presentation/widgets/availability_feedback.dart';
import 'package:tennishub/features/courts/presentation/widgets/availability_grid.dart';
import 'package:tennishub/features/courts/presentation/widgets/booking_steps.dart';
import 'package:tennishub/features/courts/presentation/widgets/booking_summary.dart';
import 'package:tennishub/features/courts/presentation/widgets/date_selector.dart';

/// Página pública de consulta de quadras e horários.
class PublicHomePage extends ConsumerStatefulWidget {
  const PublicHomePage({super.key});

  @override
  ConsumerState<PublicHomePage> createState() => _PublicHomePageState();
}

class _PublicHomePageState extends ConsumerState<PublicHomePage> {
  CourtDaySchedule? _selectedCourt;
  TimeSlot? _selectedSlot;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      ref.read(availabilityControllerProvider.notifier).loadAvailability();
    });
  }

  void _selectSlot(CourtDaySchedule court, TimeSlot slot) {
    if (!slot.isFree) return;

    setState(() {
      _selectedCourt = court;
      _selectedSlot = slot;
    });
  }

  void _selectDate(DateTime date) {
    final state = ref.read(availabilityControllerProvider);

    if (DateUtils.isSameDay(date, state.selectedDate)) {
      return;
    }

    setState(() {
      _selectedCourt = null;
      _selectedSlot = null;
    });

    ref.read(availabilityControllerProvider.notifier).selectDate(date);
  }

  void _continueBooking() {
    if (_selectedCourt == null ||
        _selectedSlot == null ||
        !_selectedSlot!.isFree) {
      return;
    }

    // O encaminhamento para a próxima etapa será
    // implementado no próximo commit.
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Horário selecionado.')));
  }

  Widget _buildAvailability(
    AvailabilityState state,
    AvailabilityController controller,
  ) {
    switch (state.status) {
      case AvailabilityStatus.initial:
      case AvailabilityStatus.loading:
        return const AvailabilityLoading();

      case AvailabilityStatus.failure:
        return AvailabilityError(
          onRetry: () {
            controller.loadAvailability();
          },
        );

      case AvailabilityStatus.success:
        final availability = state.availability;

        if (availability == null || !state.hasFreeSlots) {
          final date = state.selectedDate;

          final nextDay = DateTime(date.year, date.month, date.day + 1);

          return AvailabilityEmpty(
            onNextDay: nextDay.isAfter(controller.lastAllowedDate)
                ? null
                : () => _selectDate(nextDay),
          );
        }

        return AvailabilityGrid(
          availability: availability,
          selectedCourtId: _selectedCourt?.courtId,
          selectedStartsAt: _selectedSlot?.startsAt,
          onSlotSelected: _selectSlot,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final isWideScreen = MediaQuery.sizeOf(context).width >= 1000;

    final availabilityState = ref.watch(availabilityControllerProvider);

    final controller = ref.read(availabilityControllerProvider.notifier);

    final availabilityContent = _buildAvailability(
      availabilityState,
      controller,
    );

    final canShowSelection =
        availabilityState.status == AvailabilityStatus.success &&
        availabilityState.hasFreeSlots;

    final summary = BookingSummary(
      court: canShowSelection ? _selectedCourt : null,
      slot: canShowSelection ? _selectedSlot : null,
      onContinue: _continueBooking,
    );

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
              onDateSelected: _selectDate,
            ),
            const SizedBox(height: AppSpacing.lg),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 850) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: availabilityContent),
                      const SizedBox(width: AppSpacing.lg),
                      SizedBox(width: 300, child: summary),
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    availabilityContent,
                    const SizedBox(height: AppSpacing.lg),
                    summary,
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
