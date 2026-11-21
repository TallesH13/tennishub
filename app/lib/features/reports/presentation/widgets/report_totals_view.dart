import 'package:material_ui/material_ui.dart';
import 'package:tennishub/core/formatting/br_format.dart';
import 'package:tennishub/core/theme/app_spacing.dart';
import 'package:tennishub/features/reports/domain/rental_report.dart';

/// Chaves dos cartões de totais, para os testes encontrarem cada um.
abstract final class ReportTotalsKeys {
  static const Key count = Key('report-total-count');
  static const Key hours = Key('report-total-hours');
  static const Key value = Key('report-total-value');
}

/// Totais do relatório: gerais (locações, horas e valor) e por quadra.
class ReportTotalsView extends StatelessWidget {
  const ReportTotalsView({super.key, required this.report});

  final RentalReport report;

  @override
  Widget build(BuildContext context) {
    final totals = report.totals;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            _TotalCard(
              key: ReportTotalsKeys.count,
              label: 'Locações',
              value: '${totals.count}',
            ),
            _TotalCard(
              key: ReportTotalsKeys.hours,
              label: 'Horas locadas',
              value: '${totals.hours} h',
            ),
            _TotalCard(
              key: ReportTotalsKeys.value,
              label: 'Valor total',
              value: _valueText(totals.valueCents),
              note: totals.valueCents == null
                  ? 'Nenhuma quadra com valor por hora'
                  : null,
            ),
          ],
        ),
        if (report.byCourt.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text('Por quadra', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Quadra')),
                  DataColumn(label: Text('Locações'), numeric: true),
                  DataColumn(label: Text('Horas'), numeric: true),
                  DataColumn(label: Text('Valor'), numeric: true),
                ],
                rows: [
                  for (final court in report.byCourt)
                    DataRow(
                      cells: [
                        DataCell(Text(court.courtName)),
                        DataCell(Text('${court.totals.count}')),
                        DataCell(Text('${court.totals.hours}')),
                        DataCell(Text(_valueText(court.totals.valueCents))),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  static String _valueText(int? cents) {
    return cents == null ? '—' : BrFormat.money(cents);
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({
    super.key,
    required this.label,
    required this.value,
    this.note,
  });

  static const double _width = 220;

  final String label;
  final String value;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      width: _width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                value,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (note != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(note!, style: textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
