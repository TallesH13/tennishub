import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tennishub/core/formatting/br_date_input_formatter.dart';
import 'package:tennishub/core/formatting/br_format.dart';
import 'package:tennishub/core/theme/app_spacing.dart';
import 'package:tennishub/core/time/clock.dart';
import 'package:tennishub/features/reports/domain/report_filter.dart';
import 'package:tennishub/features/reports/presentation/state/reports_controller.dart';
import 'package:tennishub/features/reports/presentation/state/reports_state.dart';

/// Chaves dos campos do formulário, para os testes encontrarem cada um.
abstract final class ReportFilterKeys {
  static const Key from = Key('report-filter-from');
  static const Key to = Key('report-filter-to');
  static const Key client = Key('report-filter-client');
  static const Key court = Key('report-filter-court');
  static const Key submit = Key('report-filter-submit');
}

/// Formulário do relatório: período (obrigatório), cliente e quadra
/// (opcionais) e atalhos "Este mês" e "Mês passado".
class ReportFilterForm extends ConsumerStatefulWidget {
  const ReportFilterForm({super.key});

  @override
  ConsumerState<ReportFilterForm> createState() => _ReportFilterFormState();
}

class _ReportFilterFormState extends ConsumerState<ReportFilterForm> {
  static const double _dateFieldWidth = 180;
  static const double _clientFieldWidth = 300;
  static const double _courtFieldWidth = 240;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _from;
  late final TextEditingController _to;
  late final TextEditingController _client;
  String? _courtId;

  /// Só mostra os erros depois da primeira tentativa de gerar, para não
  /// avisar enquanto a pessoa ainda está digitando a primeira data.
  bool _showErrors = false;

  @override
  void initState() {
    super.initState();
    final filter = ref.read(reportsControllerProvider).filter;
    _from = TextEditingController(text: BrFormat.date(filter.from));
    _to = TextEditingController(text: BrFormat.date(filter.to));
    _client = TextEditingController(text: filter.client ?? '');
    _courtId = filter.courtId;
  }

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    _client.dispose();
    super.dispose();
  }

  String? _validateDate(String? value, String emptyMessage) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return emptyMessage;
    }
    if (BrFormat.parseDate(text) == null) {
      return 'Data inválida. Use dd/mm/aaaa.';
    }
    return null;
  }

  String? _validateFrom(String? value) {
    return _validateDate(value, 'Informe a data inicial.');
  }

  String? _validateTo(String? value) {
    final dateError = _validateDate(value, 'Informe a data final.');
    if (dateError != null) {
      return dateError;
    }

    final from = BrFormat.parseDate(_from.text);
    final to = BrFormat.parseDate(value!);
    if (from == null || to == null) {
      return null;
    }

    return switch (ReportFilter(from: from, to: to).periodError) {
      ReportPeriodError.endBeforeStart =>
        'A data final não pode ser anterior à inicial.',
      ReportPeriodError.tooLong => 'O período não pode passar de 1 ano.',
      null => null,
    };
  }

  void _applyPreset(ReportFilter preset) {
    setState(() {
      _from.text = BrFormat.date(preset.from);
      _to.text = BrFormat.date(preset.to);
    });
  }

  void _submit() {
    setState(() => _showErrors = true);
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final client = _client.text.trim();
    final filter = ReportFilter(
      from: BrFormat.parseDate(_from.text)!,
      to: BrFormat.parseDate(_to.text)!,
      client: client.isEmpty ? null : client,
      courtId: _courtId,
    );
    unawaited(ref.read(reportsControllerProvider.notifier).generate(filter));
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(
      reportsControllerProvider.select(
        (state) => state.status == ReportStatus.loading,
      ),
    );
    final courts = ref.watch(reportCourtsProvider).value ?? const [];
    final today = ref.watch(clockProvider)();

    return SizedBox(
      width: double.infinity,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            autovalidateMode: _showErrors
                ? AutovalidateMode.always
                : AutovalidateMode.disabled,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Período e filtros',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  crossAxisAlignment: WrapCrossAlignment.start,
                  children: [
                    SizedBox(
                      width: _dateFieldWidth,
                      child: _DateField(
                        fieldKey: ReportFilterKeys.from,
                        controller: _from,
                        label: 'Data inicial',
                        validator: _validateFrom,
                        onSubmitted: _submit,
                      ),
                    ),
                    SizedBox(
                      width: _dateFieldWidth,
                      child: _DateField(
                        fieldKey: ReportFilterKeys.to,
                        controller: _to,
                        label: 'Data final',
                        validator: _validateTo,
                        onSubmitted: _submit,
                      ),
                    ),
                    SizedBox(
                      width: _clientFieldWidth,
                      child: TextFormField(
                        key: ReportFilterKeys.client,
                        controller: _client,
                        decoration: const InputDecoration(
                          labelText: 'Cliente (nome ou telefone)',
                          hintText: 'Todos os clientes',
                        ),
                        textInputAction: TextInputAction.search,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                    ),
                    SizedBox(
                      width: _courtFieldWidth,
                      child: DropdownButtonFormField<String?>(
                        key: ReportFilterKeys.court,
                        initialValue: _courtId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Quadra'),
                        items: [
                          const DropdownMenuItem<String?>(
                            child: Text(
                              'Todas as quadras',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          for (final court in courts)
                            DropdownMenuItem<String?>(
                              value: court.id,
                              child: Text(
                                court.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (value) => setState(() => _courtId = value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ActionChip(
                      label: const Text('Este mês'),
                      onPressed: () =>
                          _applyPreset(ReportFilter.thisMonth(today)),
                    ),
                    ActionChip(
                      label: const Text('Mês passado'),
                      onPressed: () =>
                          _applyPreset(ReportFilter.lastMonth(today)),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    FilledButton.icon(
                      key: ReportFilterKeys.submit,
                      onPressed: isLoading ? null : _submit,
                      icon: const Icon(Icons.search),
                      label: const Text('Gerar relatório'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Campo de data com máscara `dd/mm/aaaa`.
class _DateField extends StatelessWidget {
  const _DateField({
    required this.fieldKey,
    required this.controller,
    required this.label,
    required this.validator,
    required this.onSubmitted,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String> validator;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: fieldKey,
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: 'dd/mm/aaaa',
        prefixIcon: const Icon(Icons.calendar_today_outlined),
      ),
      keyboardType: TextInputType.number,
      inputFormatters: const [BrDateInputFormatter()],
      validator: validator,
      textInputAction: TextInputAction.search,
      onFieldSubmitted: (_) => onSubmitted(),
    );
  }
}
