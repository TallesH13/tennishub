import 'package:flutter_test/flutter_test.dart';
import 'package:tennishub/core/fake/fake_backend.dart';
import 'package:tennishub/core/network/api_exception.dart';
import 'package:tennishub/features/courts/data/fake_courts_repository.dart';
import 'package:tennishub/features/courts/domain/availability.dart';
import 'package:tennishub/features/courts/domain/court.dart';
import 'package:tennishub/features/courts/domain/court_schedule.dart';

/// Terça, 01/12/2026, 9h.
final DateTime now = DateTime(2026, 12, 1, 9);

void main() {
  late FakeBackend backend;
  late FakeCourtsRepository courts;
  late FakeCourtScheduleRepository schedule;

  setUp(() {
    backend = FakeBackend(clock: () => now);
    courts = FakeCourtsRepository(backend);
    schedule = FakeCourtScheduleRepository(backend, today: () => now);
  });

  group('quadras', () {
    test('a área pública só vê as quadras ativas', () async {
      await courts.updateCourt(
        '4',
        CourtInput(name: 'Quadra 4', unavailableFrom: DateTime(2026, 12, 1)),
      );

      expect((await courts.listCourts()).map((court) => court.name), [
        'Quadra 1',
        'Quadra 2',
        'Quadra Central',
      ]);
      expect(await courts.listAllCourts(), hasLength(4));
    });

    test('cadastra e edita quadra', () async {
      final created = await courts.createCourt(
        const CourtInput(name: ' Quadra 5 ', hourlyPriceCents: 9000),
      );
      final edited = await courts.updateCourt(
        created.id,
        const CourtInput(name: 'Quadra Coberta'),
      );

      expect(created.name, 'Quadra 5');
      expect(edited.name, 'Quadra Coberta');
      expect(edited.hourlyPriceCents, isNull);
    });

    test('recusa nome vazio, nome repetido e quadra inexistente', () async {
      await expectLater(
        courts.createCourt(const CourtInput(name: '  ')),
        throwsA(isA<ValidationException>()),
      );
      await expectLater(
        courts.createCourt(const CourtInput(name: 'quadra 1')),
        throwsA(
          isA<ConflictException>().having(
            (e) => e.code,
            'code',
            'COURT_NAME_TAKEN',
          ),
        ),
      );
      await expectLater(
        courts.updateCourt('99', const CourtInput(name: 'Nova')),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('mostra os horários do dia', () async {
      final day = await courts.fetchAvailability(DateTime(2026, 12, 2));

      expect(day.hasFreeSlots, isTrue);
      expect(day.courts.first.slots.first.status, SlotStatus.free);
    });

    test('domingo só tem a Quadra Central aberta', () async {
      final sunday = await courts.fetchAvailability(DateTime(2026, 12, 6));

      final central = sunday.courts.firstWhere(
        (court) => court.courtName == 'Quadra Central',
      );
      final court1 = sunday.courts.firstWhere(
        (court) => court.courtName == 'Quadra 1',
      );
      expect(central.slots.where((slot) => slot.isFree), isNotEmpty);
      expect(
        court1.slots.every((slot) => slot.status == SlotStatus.closed),
        isTrue,
      );
    });
  });

  group('horários e bloqueios', () {
    test('lê o horário em vigor e salva uma nova vigência', () async {
      final current = await schedule.fetchOpeningHours('1');
      expect(current?.hoursOn(DateTime(2026, 12, 2)), contains(7));

      final update = await schedule.saveOpeningHours(
        '1',
        OpeningHours(
          validFrom: DateTime(2026, 12, 10),
          ranges: const [OpeningRange(weekday: 4, startHour: 9, endHour: 12)],
        ),
      );

      expect(update.affectedBookings, 0);
      expect(update.openingHours.ranges.single.toJson(), {
        'weekday': 4,
        'startHour': 9,
        'endHour': 12,
      });
    });

    test('recusa faixa com fechamento antes da abertura', () async {
      await expectLater(
        schedule.saveOpeningHours(
          '1',
          OpeningHours(
            validFrom: DateTime(2026, 12, 10),
            ranges: const [OpeningRange(weekday: 1, startHour: 18, endHour: 9)],
          ),
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test(
      'cria, lista e remove bloqueios; o bloqueio fecha o horário',
      () async {
        final block = await schedule.createBlock(
          '1',
          ScheduleBlockInput(
            startsAt: DateTime(2026, 12, 2, 10),
            endsAt: DateTime(2026, 12, 2, 12),
            reason: 'Torneio',
          ),
        );

        expect((await schedule.listBlocks('1')).map((b) => b.reason), [
          'Torneio',
        ]);
        expect(block.covers(DateTime(2026, 12, 2, 11)), isTrue);
        expect(block.covers(DateTime(2026, 12, 2, 12)), isFalse);
        final day = await courts.fetchAvailability(DateTime(2026, 12, 2));
        final slot = day.courts.first.slots.firstWhere(
          (s) => s.startsAt.hour == 10,
        );
        expect(slot.status, SlotStatus.closed);

        await schedule.deleteBlock(block.id);
        expect(await schedule.listBlocks('1'), isEmpty);
        await expectLater(
          schedule.deleteBlock(block.id),
          throwsA(isA<NotFoundException>()),
        );
      },
    );

    test('bloqueio sem motivo ou com fim antes do início é recusado', () async {
      await expectLater(
        schedule.createBlock(
          '1',
          ScheduleBlockInput(
            startsAt: DateTime(2026, 12, 2, 12),
            endsAt: DateTime(2026, 12, 2, 10),
            reason: ' ',
          ),
        ),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.fieldErrors.keys,
            'campos',
            containsAll(['endsAt', 'reason']),
          ),
        ),
      );
    });
  });
}
