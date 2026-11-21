import 'package:flutter_test/flutter_test.dart';
import 'package:tennishub/core/network/api_exception.dart';
import 'package:tennishub/features/courts/data/http_courts_repository.dart';
import 'package:tennishub/features/courts/domain/availability.dart';
import 'package:tennishub/features/courts/domain/court.dart';
import 'package:tennishub/features/courts/domain/court_schedule.dart';

import '../../../support/api_samples.dart';
import '../../../support/api_test_support.dart';

void main() {
  test('lê as quadras, com valor e data de remoção opcionais', () async {
    final api = FakeApi((_) async => jsonResponse(courtsResponse));

    final courts = await HttpCourtsRepository(api.client).listCourts();

    expect(api.lastRequest.url.path, '/api/courts');
    expect(courts.map((court) => court.id), ['1', '4']);
    expect(courts.first.hourlyPriceCents, 8000);
    expect(courts.last.hourlyPriceCents, isNull);
    expect(courts.last.unavailableFrom, DateTime(2026, 12, 15));
    expect(courts.last.isAvailableOn(DateTime(2026, 12, 14, 20)), isTrue);
    expect(courts.last.isAvailableOn(DateTime(2026, 12, 15)), isFalse);
  });

  test('lê os horários do dia', () async {
    final api = FakeApi((_) async => jsonResponse(availabilityResponse));

    final day = await HttpCourtsRepository(api.client)
        .fetchAvailability(DateTime(2026, 12, 2, 15, 30));

    expect(
      api.lastRequest.url.toString(),
      'http://api.test/api/availability?date=2026-12-02',
    );
    expect(day.date, DateTime(2026, 12, 2));
    expect(day.courts.single.courtName, 'Quadra 1');
    expect(day.courts.single.slots.map((slot) => slot.status), [
      SlotStatus.closed,
      SlotStatus.free,
      SlotStatus.busy,
    ]);
    expect(day.hasFreeSlots, isTrue);
  });

  test('cadastra quadra no painel', () async {
    final api = FakeApi(
      (_) async => jsonResponse({
        'court': {
          'id': 5,
          'name': 'Quadra 5',
          'hourlyPriceCents': 9000,
          'unavailableFrom': null,
        },
      }, 201),
      token: sampleToken,
    );

    final court = await HttpCourtsRepository(
      api.client,
    ).createCourt(const CourtInput(name: ' Quadra 5 ', hourlyPriceCents: 9000));

    expect(api.lastRequest.url.path, '/api/owner/courts');
    expect(api.lastBody, {
      'name': 'Quadra 5',
      'hourlyPriceCents': 9000,
      'unavailableFrom': null,
    });
    expect(court.id, '5');
  });

  test('nome repetido traz o conflito com a mensagem da API', () async {
    final api = FakeApi(
      (_) async => jsonResponse(const {
        'error': {
          'code': 'COURT_NAME_TAKEN',
          'message': 'Já existe uma quadra com esse nome.',
        },
      }, 409),
      token: sampleToken,
    );

    await expectLater(
      HttpCourtsRepository(api.client)
          .createCourt(const CourtInput(name: 'Quadra 1')),
      throwsA(
        isA<ConflictException>().having(
          (e) => e.code,
          'code',
          'COURT_NAME_TAKEN',
        ),
      ),
    );
  });

  test(
    'salva nova vigência de horário e informa as reservas afetadas',
    () async {
      final api = FakeApi(
        (_) async => jsonResponse(openingHoursUpdateResponse),
        token: sampleToken,
      );
      final hours = OpeningHours(
        validFrom: DateTime(2026, 12, 1),
        ranges: const [OpeningRange(weekday: 1, startHour: 7, endHour: 22)],
      );

      final update = await HttpCourtScheduleRepository(api.client)
          .saveOpeningHours('2', hours);

      expect(api.lastRequest.url.path, '/api/owner/courts/2/opening-hours');
      expect(api.lastBody, {
        'validFrom': '2026-12-01',
        'ranges': [
          {'weekday': 1, 'startHour': 7, 'endHour': 22},
        ],
      });
      expect(update.affectedBookings, 2);
      expect(update.openingHours.hoursOn(DateTime(2026, 12, 7)), {
        for (var h = 7; h < 22; h++) h,
      });
    },
  );

  test('quadra sem horário cadastrado devolve null', () async {
    final api = FakeApi(
      (_) async => jsonResponse({'openingHours': null}),
      token: sampleToken,
    );

    expect(
      await HttpCourtScheduleRepository(api.client).fetchOpeningHours('3'),
      isNull,
    );
  });

  test('remove bloqueio', () async {
    final api = FakeApi(
      (_) async => jsonResponse(null, 204),
      token: sampleToken,
    );

    await HttpCourtScheduleRepository(api.client).deleteBlock('9');

    expect(api.lastRequest.method, 'DELETE');
    expect(api.lastRequest.url.path, '/api/owner/blocks/9');
  });

  test('painel lista todas as quadras e edita uma', () async {
    final api = FakeApi(
      (request) async => request.method == 'GET'
          ? jsonResponse(courtsResponse)
          : jsonResponse({
              'court': {
                'id': 4,
                'name': 'Quadra 4',
                'hourlyPriceCents': 7000,
                'unavailableFrom': '2026-12-15',
              },
            }),
      token: sampleToken,
    );
    final repository = HttpCourtsRepository(api.client);

    expect(await repository.listAllCourts(), hasLength(2));
    expect(api.lastRequest.url.path, '/api/owner/courts');

    final court = await repository.updateCourt(
      '4',
      CourtInput(
        name: 'Quadra 4',
        hourlyPriceCents: 7000,
        unavailableFrom: DateTime(2026, 12, 15),
      ),
    );
    expect(api.lastRequest.method, 'PUT');
    expect(api.lastRequest.url.path, '/api/owner/courts/4');
    expect(api.lastBody, {
      'name': 'Quadra 4',
      'hourlyPriceCents': 7000,
      'unavailableFrom': '2026-12-15',
    });
    expect(court.unavailableFrom, DateTime(2026, 12, 15));
  });

  test('lê o horário em vigor de uma quadra', () async {
    final api = FakeApi(
      (_) async => jsonResponse({
        'openingHours': openingHoursUpdateResponse['openingHours'],
      }),
      token: sampleToken,
    );

    final hours = await HttpCourtScheduleRepository(api.client)
        .fetchOpeningHours('2');

    expect(api.lastRequest.url.path, '/api/owner/courts/2/opening-hours');
    expect(hours?.validFrom, DateTime(2026, 12, 1));
    expect(hours?.ranges, hasLength(2));
    expect(hours?.hoursOn(DateTime(2026, 12, 5)), {
      for (var h = 8; h < 18; h++) h,
    });
  });

  test('lista e cria bloqueios', () async {
    const block = {
      'id': 9,
      'courtId': 2,
      'startsAt': '2026-12-05T11:00:00.000Z',
      'endsAt': '2026-12-05T15:00:00.000Z',
      'reason': 'Manutenção do piso',
    };
    final api = FakeApi(
      (request) async => request.method == 'GET'
          ? jsonResponse({
              'blocks': [block],
            })
          : jsonResponse({'block': block}, 201),
      token: sampleToken,
    );
    final repository = HttpCourtScheduleRepository(api.client);

    final blocks = await repository.listBlocks('2');
    expect(api.lastRequest.url.path, '/api/owner/courts/2/blocks');
    expect(blocks.single.reason, 'Manutenção do piso');

    final created = await repository.createBlock(
      '2',
      ScheduleBlockInput(
        startsAt: DateTime.utc(2026, 12, 5, 11),
        endsAt: DateTime.utc(2026, 12, 5, 15),
        reason: ' Manutenção do piso ',
      ),
    );
    expect(api.lastRequest.method, 'POST');
    expect(api.lastBody, {
      'startsAt': '2026-12-05T11:00:00.000Z',
      'endsAt': '2026-12-05T15:00:00.000Z',
      'reason': 'Manutenção do piso',
    });
    expect(created.id, '9');
    expect(created.courtId, '2');
  });
}
