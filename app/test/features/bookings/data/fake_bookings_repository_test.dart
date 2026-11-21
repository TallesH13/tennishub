import 'package:flutter_test/flutter_test.dart';
import 'package:tennishub/core/fake/fake_backend.dart';
import 'package:tennishub/core/network/api_exception.dart';
import 'package:tennishub/features/bookings/data/fake_bookings_repository.dart';
import 'package:tennishub/features/bookings/domain/booking.dart';

/// Terça, 01/12/2026, 9h. Quarta (02/12) já tem reservas de exemplo.
final DateTime now = DateTime(2026, 12, 1, 9);

void main() {
  late FakeBookingsRepository bookings;
  late FakeOwnerBookingsRepository owner;

  setUp(() {
    final backend = FakeBackend(clock: () => now);
    bookings = FakeBookingsRepository(backend);
    owner = FakeOwnerBookingsRepository(backend);
  });

  test('o cliente reserva, consulta, remarca e cancela', () async {
    final created = await bookings.createBooking(
      BookingRequest(
        courtId: '1',
        startsAt: DateTime(2026, 12, 2, 10),
        customerName: 'Lucas Teixeira',
        customerPhone: '(31) 99251-7740',
      ),
    );

    final found = await bookings.findBooking(
      code: created.code.toLowerCase(),
      phone: '31992517740',
    );
    expect(found.id, created.id);
    expect(found.endsAt, DateTime(2026, 12, 2, 11));

    final moved = await bookings.rescheduleBooking(
      code: created.code,
      phone: '31992517740',
      courtId: '3',
      startsAt: DateTime(2026, 12, 2, 11),
    );
    expect(moved.courtName, 'Quadra Central');

    final cancelled = await bookings.cancelBooking(
      code: created.code,
      phone: '31992517740',
    );
    expect(cancelled.isConfirmed, isFalse);
  });

  test('o proprietário lista, realoca e cancela', () async {
    final day = await owner.listBookings(
      BookingQuery(date: DateTime(2026, 12, 2), courtId: '1'),
    );
    expect(day.map((booking) => booking.startsAt.hour), [18, 19]);

    final relocated = await owner.relocateBooking(
      day.first.id,
      courtId: '2',
      startsAt: DateTime(2026, 12, 2, 20),
      reason: 'Manutenção da Quadra 1',
    );
    expect(relocated.courtId, '2');
    expect(relocated.relocationReason, 'Manutenção da Quadra 1');

    final cancelled = await owner.cancelBooking(
      day.last.id,
      reason: 'Chuva forte',
    );
    expect(cancelled.cancelledBy, CancelledBy.owner);
    expect(cancelled.cancellationReason, 'Chuva forte');

    final onlyCancelled = await owner.listBookings(
      BookingQuery(
        date: DateTime(2026, 12, 2),
        status: BookingStatus.cancelled,
      ),
    );
    expect(onlyCancelled.single.id, day.last.id);
  });

  test(
    'realocar para horário ocupado ou agendamento inexistente falha',
    () async {
      final day = await owner.listBookings(
        BookingQuery(date: DateTime(2026, 12, 2), courtId: '1'),
      );

      await expectLater(
        owner.relocateBooking(
          day.first.id,
          courtId: '1',
          startsAt: DateTime(2026, 12, 2, 19),
          reason: 'Teste',
        ),
        throwsA(isA<SlotUnavailableException>()),
      );
      await expectLater(
        owner.cancelBooking('999', reason: 'Teste'),
        throwsA(isA<NotFoundException>()),
      );
    },
  );

  test('não reserva em quadra inexistente', () async {
    await expectLater(
      bookings.createBooking(
        BookingRequest(
          courtId: '99',
          startsAt: DateTime(2026, 12, 2, 10),
          customerName: 'Lucas Teixeira',
          customerPhone: '31992517740',
        ),
      ),
      throwsA(isA<NotFoundException>()),
    );
  });

  test('o pedido de reserva é enviado com telefone só em dígitos', () {
    final json = BookingRequest(
      courtId: '1',
      startsAt: DateTime.utc(2026, 12, 2, 13),
      customerName: ' Ana ',
      customerPhone: '(31) 98765-4321',
    ).toJson();

    expect(json['customerPhone'], '31987654321');
    expect(json['customerName'], 'Ana');
    expect(onlyDigits('31 9-87'), '31987');
  });
}
