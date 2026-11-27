import 'package:tennishub/features/courts/domain/availability.dart';

enum AvailabilityStatus { initial, loading, success, failure }

final class AvailabilityState {
  const AvailabilityState({
    required this.selectedDate,
    this.status = AvailabilityStatus.initial,
    this.availability,
    this.errorMessage,
  });

  final DateTime selectedDate;
  final AvailabilityStatus status;
  final DayAvailability? availability;
  final String? errorMessage;

  bool get hasFreeSlots => availability?.hasFreeSlots ?? false;
}
