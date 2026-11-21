import 'package:tennishub/core/network/api_client.dart';
import 'package:tennishub/core/network/json_reader.dart';
import 'package:tennishub/features/bookings/domain/booking.dart';
import 'package:tennishub/features/bookings/domain/bookings_repository.dart';

/// [BookingsRepository] ligado à API. Contrato em `docs/api.md`.
///
/// Código e telefone vão no corpo (POST), nunca na URL, para não ficarem em
/// logs de servidor nem no histórico do navegador.
class HttpBookingsRepository implements BookingsRepository {
  HttpBookingsRepository(this._api);

  final ApiClient _api;

  @override
  Future<Booking> createBooking(BookingRequest request) async {
    return _booking(await _api.post('/bookings', body: request.toJson()));
  }

  @override
  Future<Booking> findBooking({
    required String code,
    required String phone,
  }) async {
    return _booking(
      await _api.post('/bookings/lookup', body: _identity(code, phone)),
    );
  }

  @override
  Future<Booking> cancelBooking({
    required String code,
    required String phone,
  }) async {
    return _booking(
      await _api.post('/bookings/cancel', body: _identity(code, phone)),
    );
  }

  @override
  Future<Booking> rescheduleBooking({
    required String code,
    required String phone,
    required String courtId,
    required DateTime startsAt,
  }) async {
    final body = {
      ..._identity(code, phone),
      'courtId': courtId,
      'startsAt': formatApiDateTime(startsAt),
    };
    return _booking(await _api.post('/bookings/reschedule', body: body));
  }

  static JsonMap _identity(String code, String phone) => {
    'code': code.trim().toUpperCase(),
    'phone': onlyDigits(phone),
  };
}

/// [OwnerBookingsRepository] ligado à API. Contrato em `docs/api.md`.
class HttpOwnerBookingsRepository implements OwnerBookingsRepository {
  HttpOwnerBookingsRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<Booking>> listBookings(BookingQuery query) async {
    final data = await _api.get('/owner/bookings', query: query.toQuery());
    return parseResponse(
      () => [
        for (final booking in asJsonMap(data).readList('bookings'))
          Booking.fromJson(booking),
      ],
    );
  }

  @override
  Future<Booking> relocateBooking(
    String bookingId, {
    required String courtId,
    required DateTime startsAt,
    required String reason,
  }) async {
    final body = {
      'courtId': courtId,
      'startsAt': formatApiDateTime(startsAt),
      'reason': reason.trim(),
    };
    return _booking(
      await _api.post('/owner/bookings/$bookingId/relocate', body: body),
    );
  }

  @override
  Future<Booking> cancelBooking(
    String bookingId, {
    required String reason,
  }) async {
    return _booking(
      await _api.post(
        '/owner/bookings/$bookingId/cancel',
        body: {'reason': reason.trim()},
      ),
    );
  }
}

Booking _booking(Object? data) =>
    parseResponse(() => Booking.fromJson(asJsonMap(data).readMap('booking')));
