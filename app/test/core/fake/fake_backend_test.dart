import 'package:flutter_test/flutter_test.dart';
import 'package:tennishub/core/fake/fake_backend.dart';
import 'package:tennishub/core/network/api_exception.dart';
import 'package:tennishub/features/bookings/domain/booking.dart';
import 'package:tennishub/features/courts/domain/availability.dart';
import 'package:tennishub/features/courts/domain/court_schedule.dart';

/// "Agora" fixo: terça, 01/12/2026, 9h. O dia seguinte (quarta) já tem
/// reservas de exemplo: Quadra 1 às 18h (Ana) e 19h, Quadra 2 às 19h e
/// Quadra Central às 18h.
final DateTime now = DateTime(2026, 12, 1, 9);
final DateTime wednesday = DateTime(2026, 12, 2);

DateTime at(DateTime day, int hour) =>
    DateTime(day.year, day.month, day.day, hour);

const String anaPhone = '31987654321';

void main() {
  late FakeBackend backend;

  setUp(() => backend = FakeBackend(clock: () => now));

  BookingRequest request(
    String courtId,
    int hour, {
    String name = 'Lucas Teixeira',
    String phone = '31992517740',
  }) {
    return BookingRequest(
      courtId: courtId,
      startsAt: at(wednesday, hour),
      customerName: name,
      customerPhone: phone,
    );
  }

  group('disponibilidade', () {
    test('mostra as quadras ativas com os horários do dia', () {
      final day = backend.availability(wednesday);

      expect(day.courts.map((court) => court.courtName), [
        'Quadra 1',
        'Quadra 2',
        'Quadra Central',
        'Quadra 4',
      ]);
      final court1 = day.courts.first;
      expect(court1.slots.first.startsAt, at(wednesday, 7));
      expect(court1.slots.last.startsAt, at(wednesday, 21));
      expect(
        court1.slots.firstWhere((slot) => slot.startsAt.hour == 18).status,
        SlotStatus.busy,
      );
      expect(
        court1.slots.firstWhere((slot) => slot.startsAt.hour == 10).status,
        SlotStatus.free,
      );
    });

    test('horários que já passaram ficam fechados', () {
      final today = backend.availability(now);
      final slots = today.courts.first.slots;

      expect(
        slots.firstWhere((slot) => slot.startsAt.hour == 8).status,
        SlotStatus.closed,
      );
      expect(
        slots.firstWhere((slot) => slot.startsAt.hour == 10).status,
        SlotStatus.free,
      );
    });
  });

  group('reservas do cliente', () {
    test('cria a reserva com código de 8 caracteres e ocupa o horário', () {
      final booking = backend.createBooking(
        request('1', 10, phone: '(31) 99251-7740'),
      );

      expect(booking.code, matches(RegExp(r'^[A-HJ-NP-Z2-9]{8}$')));
      expect(booking.customerPhone, '31992517740');
      final slot = backend
          .availability(wednesday)
          .courts
          .first
          .slots
          .firstWhere((s) => s.startsAt.hour == 10);
      expect(slot.status, SlotStatus.busy);
    });

    test('horário já reservado lança SlotUnavailableException', () {
      expect(
        () => backend.createBooking(request('1', 18)),
        throwsA(isA<SlotUnavailableException>()),
      );
    });

    test(
      'terceira reserva do mesmo telefone no dia lança DailyLimitException',
      () {
        backend.createBooking(
          request('2', 10, name: 'Ana Paula Ribeiro', phone: anaPhone),
        );

        expect(
          () => backend.createBooking(
            request('3', 11, name: 'Ana Paula Ribeiro', phone: anaPhone),
          ),
          throwsA(isA<DailyLimitException>()),
        );
      },
    );

    test('dados inválidos trazem o erro de cada campo', () {
      expect(
        () =>
            backend.createBooking(request('1', 10, name: 'Ana', phone: '3198')),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.fieldErrors.keys,
            'campos',
            containsAll(['customerName', 'customerPhone']),
          ),
        ),
      );
    });

    test('cancelar libera o horário e não pode ser repetido', () {
      final booking = backend.createBooking(request('1', 10));

      final cancelled = backend.cancelByCustomer(
        booking.code,
        '(31) 99251-7740',
      );

      expect(cancelled.status, BookingStatus.cancelled);
      expect(cancelled.cancelledBy, CancelledBy.customer);
      expect(
        () => backend.createBooking(request('1', 10, phone: '31983905516')),
        returnsNormally,
      );
      expect(
        () => backend.cancelByCustomer(booking.code, '31992517740'),
        throwsA(isA<ConflictException>()),
      );
    });

    test('código ou telefone errado lança NotFoundException', () {
      final booking = backend.createBooking(request('1', 10));

      expect(
        () => backend.findBooking(booking.code, '31900000000'),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('remarcar move a reserva e libera o horário antigo', () {
      final booking = backend.createBooking(request('1', 10));

      final moved = backend.reschedule(
        booking.code,
        '31992517740',
        courtId: '2',
        startsAt: at(wednesday, 11),
      );

      expect(moved.courtName, 'Quadra 2');
      expect(moved.startsAt, at(wednesday, 11));
      expect(
        () => backend.createBooking(request('1', 10, phone: '31983905516')),
        returnsNormally,
      );
    });
  });

  group('painel', () {
    test('lista os agendamentos do dia em ordem de horário', () {
      final bookings = backend.ownerBookings(BookingQuery(date: wednesday));

      expect(bookings.map((booking) => booking.startsAt.hour), [
        18,
        18,
        19,
        19,
      ]);
    });

    test('realocar e cancelar exigem motivo', () {
      final booking = backend
          .ownerBookings(BookingQuery(date: wednesday))
          .first;

      expect(
        () => backend.relocate(
          booking.id,
          courtId: '2',
          startsAt: at(wednesday, 10),
          reason: ' ',
        ),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => backend.cancelByOwner(booking.id, reason: ''),
        throwsA(isA<ValidationException>()),
      );

      final relocated = backend.relocate(
        booking.id,
        courtId: '2',
        startsAt: at(wednesday, 10),
        reason: 'Chuva',
      );
      expect(relocated.relocationReason, 'Chuva');
    });

    test(
      'novo horário de funcionamento marca as reservas que ficaram de fora',
      () {
        final update = backend.saveOpeningHours(
          '1',
          OpeningHours(
            validFrom: wednesday,
            ranges: const [OpeningRange(weekday: 3, startHour: 7, endHour: 18)],
          ),
        );

        // Quarta às 18h e 19h, e quinta às 20h (quinta ficou sem faixa).
        expect(update.affectedBookings, 3);
        final court1 = backend.ownerBookings(
          BookingQuery(date: wednesday, courtId: '1'),
        );
        expect(court1.every((booking) => booking.needsRelocation), isTrue);
      },
    );
  });
}
