import 'package:tennishub/features/courts/domain/availability.dart';

enum AvailabilityStatus { initial, loading, success, failure }

final class AvailabilityState {
  const AvailabilityState({
    required this.selectedDate,
    this.status = AvailabilityStatus.initial,
    this.availability,
    this.errorMessage,
    this.isRefreshing = false,
    this.lastUpdatedAt,
  });

  final DateTime selectedDate;
  final AvailabilityStatus status;
  final DayAvailability? availability;
  final String? errorMessage;
  final bool isRefreshing;
  final DateTime? lastUpdatedAt;

  bool get hasFreeSlots => availability?.hasFreeSlots ?? false;

  bool get isLoading => status == AvailabilityStatus.loading;

  bool get hasError => status == AvailabilityStatus.failure;

  AvailabilityState copyWith({
    DateTime? selectedDate,
    AvailabilityStatus? status,
    DayAvailability? availability,
    String? errorMessage,
    bool? isRefreshing,
    DateTime? lastUpdatedAt,
    bool clearError = false,
  }) {
    return AvailabilityState(
      selectedDate: selectedDate ?? this.selectedDate,
      status: status ?? this.status,
      availability: availability ?? this.availability,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }
}
