import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tennishub/core/time/clock.dart';
import 'package:tennishub/features/courts/data/courts_providers.dart';
import 'package:tennishub/features/courts/presentation/state/availability_state.dart';

class AvailabilityController extends Notifier<AvailabilityState> {
  int _lastRequest = 0;

  DateTime get today {
    final now = ref.read(clockProvider)();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get lastAllowedDate {
    final date = today;
    return DateTime(date.year, date.month, date.day + 30);
  }

  @override
  AvailabilityState build() {
    return AvailabilityState(selectedDate: today);
  }

  Future<void> selectDate(DateTime date) async {
    final day = DateTime(date.year, date.month, date.day);

    if (day.isBefore(today) || day.isAfter(lastAllowedDate)) {
      return;
    }

    await loadAvailability(day: day);
  }

  Future<void> loadAvailability({DateTime? day}) async {
    final selectedDate = day ?? state.selectedDate;
    final request = ++_lastRequest;

    state = AvailabilityState(
      selectedDate: selectedDate,
      status: AvailabilityStatus.loading,
    );

    try {
      final availability = await ref
          .read(courtsRepositoryProvider)
          .fetchAvailability(selectedDate);

      if (!ref.mounted || request != _lastRequest) {
        return;
      }

      state = AvailabilityState(
        selectedDate: selectedDate,
        status: AvailabilityStatus.success,
        availability: availability,
      );
    } on Exception {
      if (!ref.mounted || request != _lastRequest) {
        return;
      }

      state = AvailabilityState(
        selectedDate: selectedDate,
        status: AvailabilityStatus.failure,
        errorMessage: 'Não foi possível carregar os horários',
      );
    }
  }
}

final availabilityControllerProvider =
    NotifierProvider.autoDispose<AvailabilityController, AvailabilityState>(
      AvailabilityController.new,
    );
