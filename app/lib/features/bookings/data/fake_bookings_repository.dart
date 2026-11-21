import 'package:tennishub/core/fake/fake_backend.dart';
import 'package:tennishub/features/bookings/domain/booking.dart';
import 'package:tennishub/features/bookings/domain/bookings_repository.dart';

/// [BookingsRepository] em memória, sobre o [FakeBackend].
class FakeBookingsRepository implements BookingsRepository {
  FakeBookingsRepository(this._backend);

  final FakeBackend _backend;

  @override
  Future<Booking> createBooking(BookingRequest request) async {
    await _backend.wait();
    return _backend.createBooking(request);
  }

  @override
  Future<Booking> findBooking({
    required String code,
    required String phone,
  }) async {
    await _backend.wait();
    return _backend.findBooking(code, phone);
  }

  @override
  Future<Booking> cancelBooking({
    required String code,
    required String phone,
  }) async {
    await _backend.wait();
    return _backend.cancelByCustomer(code, phone);
  }

  @override
  Future<Booking> rescheduleBooking({
    required String code,
    required String phone,
    required String courtId,
    required DateTime startsAt,
  }) async {
    await _backend.wait();
    return _backend.reschedule(
      code,
      phone,
      courtId: courtId,
      startsAt: startsAt,
    );
  }
}

/// [OwnerBookingsRepository] em memória, sobre o [FakeBackend].
class FakeOwnerBookingsRepository implements OwnerBookingsRepository {
  FakeOwnerBookingsRepository(this._backend);

  final FakeBackend _backend;

  @override
  Future<List<Booking>> listBookings(BookingQuery query) async {
    await _backend.wait();
    return _backend.ownerBookings(query);
  }

  @override
  Future<Booking> relocateBooking(
    String bookingId, {
    required String courtId,
    required DateTime startsAt,
    required String reason,
  }) async {
    await _backend.wait();
    return _backend.relocate(
      bookingId,
      courtId: courtId,
      startsAt: startsAt,
      reason: reason,
    );
  }

  @override
  Future<Booking> cancelBooking(
    String bookingId, {
    required String reason,
  }) async {
    await _backend.wait();
    return _backend.cancelByOwner(bookingId, reason: reason);
  }
}
