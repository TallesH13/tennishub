import 'package:material_ui/material_ui.dart';
import 'package:tennishub/core/theme/app_spacing.dart';

class DateSelector extends StatefulWidget {
  const DateSelector({
    super.key,
    required this.today,
    required this.lastAllowedDate,
    required this.selectedDate,
    required this.onDateSelected,
  });

  final DateTime today;
  final DateTime lastAllowedDate;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  @override
  State<DateSelector> createState() => _DateSelectorState();
}

class _DateSelectorState extends State<DateSelector> {
  static const int _daysPerPage = 7;

  int _offset = 0;

  @override
  void initState() {
    super.initState();
    _syncSelectedDate();
  }

  @override
  void didUpdateWidget(covariant DateSelector oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!DateUtils.isSameDay(oldWidget.selectedDate, widget.selectedDate) ||
        !DateUtils.isSameDay(oldWidget.today, widget.today)) {
      _syncSelectedDate();
    }
  }

  void _syncSelectedDate() {
    final today = DateTime.utc(
      widget.today.year,
      widget.today.month,
      widget.today.day,
    );

    final selected = DateTime.utc(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
    );

    final difference = selected.difference(today).inDays;

    _offset = difference < 0 ? 0 : (difference ~/ _daysPerPage) * _daysPerPage;
  }

  DateTime _dateAt(int offset) {
    return DateTime(
      widget.today.year,
      widget.today.month,
      widget.today.day + offset,
    );
  }

  bool get _canGoBack => _offset > 0;

  bool get _canGoForward {
    return !_dateAt(_offset + _daysPerPage).isAfter(widget.lastAllowedDate);
  }

  void _previousPage() {
    if (!_canGoBack) return;

    setState(() {
      _offset -= _daysPerPage;
    });
  }

  void _nextPage() {
    if (!_canGoForward) return;

    setState(() {
      _offset += _daysPerPage;
    });
  }

  bool _isDateEnabled(DateTime date) {
    return !date.isBefore(widget.today) &&
        !date.isAfter(widget.lastAllowedDate);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selecione o dia',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                IconButton(
                  tooltip: 'Dias anteriores',
                  onPressed: _canGoBack ? _previousPage : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (var index = 0; index < _daysPerPage; index++)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs,
                            ),
                            child: _DateCard(
                              date: _dateAt(_offset + index),
                              isSelected: DateUtils.isSameDay(
                                _dateAt(_offset + index),
                                widget.selectedDate,
                              ),
                              isEnabled: _isDateEnabled(
                                _dateAt(_offset + index),
                              ),
                              onPressed: () {
                                widget.onDateSelected(_dateAt(_offset + index));
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Próximos dias',
                  onPressed: _canGoForward ? _nextPage : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DateCard extends StatelessWidget {
  const _DateCard({
    required this.date,
    required this.isSelected,
    required this.isEnabled,
    required this.onPressed,
  });

  static const _weekdays = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

  static const _months = [
    'Jan',
    'Fev',
    'Mar',
    'Abr',
    'Mai',
    'Jun',
    'Jul',
    'Ago',
    'Set',
    'Out',
    'Nov',
    'Dez',
  ];

  final DateTime date;
  final bool isSelected;
  final bool isEnabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      width: 88,
      child: OutlinedButton(
        onPressed: isEnabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          backgroundColor: isSelected ? colors.primary : null,
          foregroundColor: isSelected ? colors.onPrimary : colors.onSurface,
          side: BorderSide(
            color: isSelected ? colors.primary : colors.outlineVariant,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.sm,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_weekdays[date.weekday - 1]),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${date.day}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(_months[date.month - 1]),
          ],
        ),
      ),
    );
  }
}
