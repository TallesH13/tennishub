import 'package:flutter_test/flutter_test.dart';
import 'package:tennishub/core/network/api_client.dart';
import 'package:tennishub/core/network/api_exception.dart';
import 'package:tennishub/features/bookings/data/http_bookings_repository.dart';
import 'package:tennishub/features/bookings/domain/booking.dart';

import '../../../support/api_samples.dart';
import '../../../support/api_test_support.dart';

void main() {
  final request = BookingRequest(
    courtId: '2',
    startsAt: DateTime.utc(2026, 12, 2, 21),
    customerName: ' Ana Paula Ribeiro ',
    customerPhone: '(31) 98765-4321',
  );

  group('cliente', () {
    test('cria a reserva com telefone só em dígitos e lê o código', () async {
      final api = FakeApi(
        (_) async => jsonResponse({'booking': bookingJson}, 201),
      );

      final booking = await HttpBookingsRepository(api.client)
          .createBooking(request);

      expect(api.lastRequest.url.path, '/api/bookings');
      expect(api.lastBody, {
        'courtId': '2',
        'startsAt': '2026-12-02T21:00:00.000Z',
        'customerName': 'Ana Paula Ribeiro',
        'customerPhone': '31987654321',
      });
      expect(booking.code, 'K7M4QX9R');
      expect(booking.courtId, '2');
      expect(booking.status, BookingStatus.confirmed);
      expect(booking.startsAt.toUtc(), DateTime.utc(2026, 12, 2, 21));
      expect(booking.endsAt.toUtc(), DateTime.utc(2026, 12, 2, 22));
    });

    test('horário tomado vira SlotUnavailableException', () async {
      final api = FakeApi((_) async => jsonResponse(slotUnavailableError, 409));

      await expectLater(
        HttpBookingsRepository(api.client).createBooking(request),
        throwsA(isA<SlotUnavailableException>()),
      );
    });

    test('limite diário vira DailyLimitException', () async {
      final api = FakeApi((_) async => jsonResponse(dailyLimitError, 409));

      await expectLater(
        HttpBookingsRepository(api.client).createBooking(request),
        throwsA(isA<DailyLimitException>()),
      );
    });

    test('busca por código e telefone no corpo, nunca na URL', () async {
      final api = FakeApi((_) async => jsonResponse({'booking': bookingJson}));

      await HttpBookingsRepository(api.client)
          .findBooking(code: ' k7m4qx9r ', phone: '(31) 98765-4321');

      expect(api.lastRequest.method, 'POST');
      expect(
        api.lastRequest.url.toString(),
        'http://api.test/api/bookings/lookup',
      );
      expect(api.lastBody, {'code': 'K7M4QX9R', 'phone': '31987654321'});
    });

    test('reserva inexistente vira NotFoundException', () async {
      final api = FakeApi((_) async => jsonResponse(bookingNotFoundError, 404));

      await expectLater(
        HttpBookingsRepository(api.client)
            .findBooking(code: 'AAAAAAAA', phone: '31987654321'),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('cancelamento lê a reserva cancelada', () async {
      final api = FakeApi(
        (_) async => jsonResponse({'booking': cancelledBookingJson}),
      );

      final booking = await HttpBookingsRepository(api.client)
          .cancelBooking(code: 'K7M4QX9R', phone: '31987654321');

      expect(api.lastRequest.url.path, '/api/bookings/cancel');
      expect(booking.status, BookingStatus.cancelled);
      expect(booking.cancelledBy, CancelledBy.customer);
    });

    test('remarcação envia a nova quadra e o novo horário', () async {
      final api = FakeApi((_) async => jsonResponse({'booking': bookingJson}));

      await HttpBookingsRepository(api.client).rescheduleBooking(
        code: 'K7M4QX9R',
        phone: '31987654321',
        courtId: '1',
        startsAt: DateTime.utc(2026, 12, 3, 22),
      );

      expect(api.lastBody, {
        'code': 'K7M4QX9R',
        'phone': '31987654321',
        'courtId': '1',
        'startsAt': '2026-12-03T22:00:00.000Z',
      });
    });

    test('falha de rede lança NetworkException', () async {
      final repository = HttpBookingsRepository(
        ApiClient(httpClient: offlineClient(), baseUrl: ''),
      );

      await expectLater(
        repository.createBooking(request),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('painel', () {
    test('lista com os filtros na URL', () async {
      final api = FakeApi(
        (_) async => jsonResponse({
          'bookings': [bookingJson],
        }),
        token: sampleToken,
      );

      final bookings = await HttpOwnerBookingsRepository(api.client)
          .listBookings(
            BookingQuery(
              date: DateTime(2026, 12, 2),
              courtId: '2',
              status: BookingStatus.confirmed,
            ),
          );

      expect(api.lastRequest.url.path, '/api/owner/bookings');
      expect(api.lastRequest.url.queryParameters, {
        'date': '2026-12-02',
        'courtId': '2',
        'status': 'confirmed',
      });
      expect(bookings.single.customerName, 'Ana Paula Ribeiro');
    });

    test('realocação envia o motivo', () async {
      final api = FakeApi(
        (_) async => jsonResponse({'booking': bookingJson}),
        token: sampleToken,
      );

      await HttpOwnerBookingsRepository(api.client).relocateBooking(
        '42',
        courtId: '1',
        startsAt: DateTime.utc(2026, 12, 2, 19),
        reason: ' Manutenção na Quadra 2 ',
      );

      expect(api.lastRequest.url.path, '/api/owner/bookings/42/relocate');
      expect(api.lastBody, {
        'courtId': '1',
        'startsAt': '2026-12-02T19:00:00.000Z',
        'reason': 'Manutenção na Quadra 2',
      });
    });

    test('cancelamento sem motivo traz o erro do campo', () async {
      final api = FakeApi(
        (_) async => jsonResponse(const {
          'error': {
            'code': 'VALIDATION_ERROR',
            'message': 'Dados inválidos.',
            'details': [
              {
                'field': 'reason',
                'message': 'Informe o motivo do cancelamento.',
              },
            ],
          },
        }, 422),
        token: sampleToken,
      );

      await expectLater(
        HttpOwnerBookingsRepository(api.client).cancelBooking('42', reason: ''),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.fieldErrors['reason'],
            'erro do motivo',
            'Informe o motivo do cancelamento.',
          ),
        ),
      );
    });
  });

  test(
    'situação desconhecida na resposta lança UnexpectedResponseException',
    () async {
      final api = FakeApi(
        (_) async => jsonResponse({
          'booking': {...bookingJson, 'status': 'pendente'},
        }),
      );

      await expectLater(
        HttpBookingsRepository(api.client)
            .findBooking(code: 'K7M4QX9R', phone: '31987654321'),
        throwsA(isA<UnexpectedResponseException>()),
      );
    },
  );
}
