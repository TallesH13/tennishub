import 'package:material_ui/material_ui.dart';
import 'package:tennishub/core/theme/app_spacing.dart';

class BookingSteps extends StatelessWidget {
  const BookingSteps({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _BookingStep(number: 1, label: 'Horário', isActive: true),
        Expanded(child: Divider()),
        _BookingStep(number: 2, label: 'Seus dados'),
        Expanded(child: Divider()),
        _BookingStep(number: 3, label: 'Confirmação'),
      ],
    );
  }
}

class _BookingStep extends StatelessWidget {
  const _BookingStep({
    required this.number,
    required this.label,
    this.isActive = false,
  });

  final int number;
  final String label;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: isActive
                ? colors.primary
                : colors.surfaceContainerHighest,
            foregroundColor: isActive
                ? colors.onPrimary
                : colors.onSurfaceVariant,
            child: Text('$number'),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            label,
            style: TextStyle(
              color: isActive ? colors.primary : colors.onSurfaceVariant,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
