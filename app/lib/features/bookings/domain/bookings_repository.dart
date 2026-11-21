import 'package:tennishub/features/bookings/domain/booking.dart';

/// Reservas feitas pelo cliente, sem login (RF02 a RF04).
///
/// Os métodos lançam `ApiException` (core/network) em caso de falha, como
/// `SlotUnavailableException` e `DailyLimitException`.
abstract interface class BookingsRepository {
  Future<Booking> createBooking(BookingRequest request);

  /// Busca a reserva pelo código e pelo telefone usado nela.
  Future<Booking> findBooking({required String code, required String phone});

  Future<Booking> cancelBooking({required String code, required String phone});

  /// Troca a quadra e/ou o horário de uma reserva confirmada.
  Future<Booking> rescheduleBooking({
    required String code,
    required String phone,
    required String courtId,
    required DateTime startsAt,
  });
}

/// Agendamentos vistos pelo proprietário (RF08, RF09).
abstract interface class OwnerBookingsRepository {
  Future<List<Booking>> listBookings(BookingQuery query);

  /// Move a reserva para outra quadra ou horário. O motivo é obrigatório.
  Future<Booking> relocateBooking(
    String bookingId, {
    required String courtId,
    required DateTime startsAt,
    required String reason,
  });

  /// Cancela a reserva. O motivo é obrigatório.
  Future<Booking> cancelBooking(String bookingId, {required String reason});
}
