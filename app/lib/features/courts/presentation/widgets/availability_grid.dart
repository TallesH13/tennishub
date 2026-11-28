import 'package:material_ui/material_ui.dart';
import 'package:tennishub/core/theme/app_colors.dart';
import 'package:tennishub/core/theme/app_spacing.dart';
import 'package:tennishub/features/courts/domain/availability.dart';

class AvailabilityGrid extends StatelessWidget {
  const AvailabilityGrid({
    super.key,
    required this.availability,
    required this.selectedCourtId,
    required this.selectedStartsAt,
    required this.onSlotSelected,
  });

  final DayAvailability availability;
  final String? selectedCourtId;
  final DateTime? selectedStartsAt;
  final void Function(CourtDaySchedule, TimeSlot) onSlotSelected;

  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final courts = availability.courts;

    final times = <DateTime>{
      for (final court in courts)
        for (final slot in court.slots) slot.startsAt,
    }.toList()..sort();

    final slotsByCourt = {
      for (final court in courts)
        court.courtId: {for (final slot in court.slots) slot.startsAt: slot},
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selecione um horário',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            const Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              children: [
                _LegendItem(label: 'Livre', color: AppColors.slotAvailable),
                _LegendItem(label: 'Ocupado', color: AppColors.slotUnavailable),
                _LegendItem(label: 'Selecionado', color: AppColors.courtGreen),
                _LegendItem(label: 'Fechado', color: Colors.transparent),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                horizontalMargin: AppSpacing.sm,
                columnSpacing: AppSpacing.md,
                columns: [
                  const DataColumn(label: Text('Horário')),
                  for (final court in courts)
                    DataColumn(label: Text(court.courtName)),
                ],
                rows: [
                  for (final time in times)
                    DataRow(
                      cells: [
                        DataCell(Text(_formatTime(time))),
                        for (final court in courts)
                          DataCell(
                            _SlotButton(
                              slot: slotsByCourt[court.courtId]?[time],
                              isSelected:
                                  selectedCourtId == court.courtId &&
                                  selectedStartsAt == time,
                              onSelected: (slot) {
                                onSlotSelected(court, slot);
                              },
                            ),
                          ),
                      ],
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

class _SlotButton extends StatelessWidget {
  const _SlotButton({
    required this.slot,
    required this.isSelected,
    required this.onSelected,
  });

  final TimeSlot? slot;
  final bool isSelected;
  final ValueChanged<TimeSlot> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final currentSlot = slot;
    final status = currentSlot?.status ?? SlotStatus.closed;

    final selected = isSelected && status == SlotStatus.free;

    final background = selected
        ? AppColors.courtGreen
        : switch (status) {
            SlotStatus.free => AppColors.slotAvailable,
            SlotStatus.busy => AppColors.slotUnavailable,
            SlotStatus.closed => Colors.transparent,
          };

    final label = selected
        ? 'Selecionado'
        : switch (status) {
            SlotStatus.free => 'Livre',
            SlotStatus.busy => 'Ocupado',
            SlotStatus.closed => 'Fechado',
          };

    return SizedBox(
      width: 120,
      height: 36,
      child: OutlinedButton(
        onPressed: currentSlot != null && currentSlot.isFree
            ? () => onSelected(currentSlot)
            : null,
        style: OutlinedButton.styleFrom(
          backgroundColor: background,
          disabledBackgroundColor: background,
          foregroundColor: selected ? Colors.white : AppColors.courtGreen,
          disabledForegroundColor: colors.onSurfaceVariant,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          side: BorderSide(
            color: status == SlotStatus.closed
                ? colors.outlineVariant
                : Colors.transparent,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(label),
      ],
    );
  }
}
