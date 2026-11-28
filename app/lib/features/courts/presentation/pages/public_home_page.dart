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

      final controller = ref.read(availabilityControllerProvider.notifier);

      controller.loadAvailability();
      controller.startAutoRefresh();
    });
  }

  void _selectSlot(CourtDaySchedule court, TimeSlot slot) {
    if (!slot.isFree) return;

    setState(() {
      _selectedCourt = court;
      _selectedSlot = slot;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedCourt = null;
      _selectedSlot = null;
    });
  }

  void _selectDate(DateTime date) {
    final state = ref.read(availabilityControllerProvider);

    if (DateUtils.isSameDay(date, state.selectedDate)) {
      return;
    }

    final controller = ref.read(availabilityControllerProvider.notifier);

    if (date.isBefore(controller.today) ||
        date.isAfter(controller.lastAllowedDate)) {
      return;
    }

    _clearSelection();

    controller.selectDate(date);
  }

  void _validateSelection(DayAvailability availability) {
    final selectedCourt = _selectedCourt;
    final selectedSlot = _selectedSlot;

    if (selectedCourt == null || selectedSlot == null) {
      return;
    }

    for (final court in availability.courts) {
      if (court.courtId != selectedCourt.courtId) {
        continue;
      }

      for (final slot in court.slots) {
        if (slot.startsAt == selectedSlot.startsAt && slot.isFree) {
          setState(() {
            _selectedCourt = court;
            _selectedSlot = slot;
          });

          return;
        }
      }
    }

    _clearSelection();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'O horário selecionado não está mais disponível. '
          'Selecione outro horário.',
        ),
      ),
    );
  }

  void _continueBooking() {
    final court = _selectedCourt;
    final slot = _selectedSlot;

    final state = ref.read(availabilityControllerProvider);

    if (court == null ||
        slot == null ||
        !slot.isFree ||
        state.status != AvailabilityStatus.success ||
        state.isRefreshing ||
        state.errorMessage != null) {
      return;
    }

    final availability = state.availability;

    if (availability == null) return;

    final isStillAvailable = availability.courts.any(
      (currentCourt) =>
          currentCourt.courtId == court.courtId &&
          currentCourt.slots.any(
            (currentSlot) =>
                currentSlot.startsAt == slot.startsAt && currentSlot.isFree,
          ),
    );

    if (!isStillAvailable) {
      _validateSelection(availability);
      return;
    }

    // Ponto de integração com o fluxo de agendamento
    // que será desenvolvido na Issue #23.
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Horário selecionado'),
          content: Text(
            'Quadra: ${court.courtName}\n'
            'Data: ${_formatDate(slot.startsAt)}\n'
            'Horário: ${_formatTime(slot.startsAt)}'
            ' - ${_formatTime(slot.endsAt)}\n\n'
            'A próxima etapa será o preenchimento '
            'dos dados da reserva.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Voltar'),
            ),
          ],
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
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

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AvailabilityEmpty(
                onNextDay: nextDay.isAfter(controller.lastAllowedDate)
                    ? null
                    : () => _selectDate(nextDay),
              ),
              if (state.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Text(
                    'Falha na atualização. '
                    'Os horários podem estar desatualizados.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          );
        }

        return AvailabilityGrid(
          availability: availability,
          selectedCourtId: _selectedCourt?.courtId,
          selectedStartsAt: _selectedSlot?.startsAt,
          onSlotSelected: _selectSlot,
          isRefreshing: state.isRefreshing,
          lastUpdatedAt: state.lastUpdatedAt,
          errorMessage: state.errorMessage,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final isWideScreen = MediaQuery.sizeOf(context).width >= 1000;

    final availabilityState = ref.watch(availabilityControllerProvider);

    final controller = ref.read(availabilityControllerProvider.notifier);

    ref.listen<AvailabilityState>(availabilityControllerProvider, (
      previous,
      next,
    ) {
      if (next.status != AvailabilityStatus.success) {
        return;
      }

      final availability = next.availability;

      if (availability == null) return;

      if (previous?.availability != availability) {
        _validateSelection(availability);
      }
    });

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

    final canContinue =
        !availabilityState.isRefreshing &&
        availabilityState.errorMessage == null;

    final summaryContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AbsorbPointer(absorbing: !canContinue, child: summary),
        if (!canContinue && _selectedSlot != null)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Text(
              availabilityState.isRefreshing
                  ? 'Aguarde a atualização dos horários.'
                  : 'Aguarde uma atualização bem-sucedida '
                        'para continuar.',
              textAlign: TextAlign.center,
            ),
          ),
      ],
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
                      SizedBox(width: 300, child: summaryContent),
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    availabilityContent,
                    const SizedBox(height: AppSpacing.lg),
                    summaryContent,
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
