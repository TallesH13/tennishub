import 'package:material_ui/material_ui.dart';
import 'package:tennishub/core/theme/app_spacing.dart';
import 'package:tennishub/features/courts/domain/availability.dart';

class BookingSummary extends StatelessWidget {
  const BookingSummary({
    super.key,
    required this.court,
    required this.slot,
    required this.onContinue,
  });

  final CourtDaySchedule? court;
  final TimeSlot? slot;
  final VoidCallback onContinue;

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

  String _formatPrice(int? cents) {
    if (cents == null) {
      return 'Não informado';
    }

    final value = (cents / 100).toStringAsFixed(2).replaceAll('.', ',');

    return 'R\$ $value';
  }

  @override
  Widget build(BuildContext context) {
    final selectedCourt = court;
    final selectedSlot = slot;

    final hasSelection =
        selectedCourt != null && selectedSlot != null && selectedSlot.isFree;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Resumo da reserva',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (hasSelection) ...[
              _SummaryItem(label: 'Quadra', value: selectedCourt.courtName),
              _SummaryItem(
                label: 'Data',
                value: _formatDate(selectedSlot.startsAt),
              ),
              _SummaryItem(
                label: 'Horário',
                value:
                    '${_formatTime(selectedSlot.startsAt)}'
                    ' - '
                    '${_formatTime(selectedSlot.endsAt)}',
              ),
              const Divider(),
              _SummaryItem(
                label: 'Valor',
                value: _formatPrice(selectedCourt.hourlyPriceCents),
              ),
            ] else ...[
              const Icon(Icons.calendar_today_outlined, size: 36),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Selecione um horário livre para continuar.',
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: hasSelection ? onContinue : null,
              child: const Text('Continuar'),
            ),
            const SizedBox(height: AppSpacing.md),
            const Divider(),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Cada reserva tem duração de 1 hora. '
              'Limite de 2 reservas por dia.',
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
