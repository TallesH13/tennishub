import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tennishub/app.dart';
import 'package:tennishub/core/router/app_router.dart';
import 'package:tennishub/core/router/app_routes.dart';
import 'package:tennishub/core/time/clock.dart';
import 'package:tennishub/features/courts/data/courts_providers.dart';
import 'package:tennishub/features/courts/domain/availability.dart';
import 'package:tennishub/features/courts/domain/court.dart';
import 'package:tennishub/features/courts/domain/courts_repository.dart';

/// Data fixa utilizada nos testes da consulta pública.
final DateTime testToday = DateTime(2026, 11, 28);

/// Disponibilidade de exemplo com horários livres,
/// ocupados e fechados.
DayAvailability sampleAvailability(
  DateTime day, {
  SlotStatus firstSlotStatus = SlotStatus.free,
}) {
  return DayAvailability(
    date: day,
    courts: [
      CourtDaySchedule(
        courtId: 'court-1',
        courtName: 'Quadra 1',
        hourlyPriceCents: 6000,
        slots: [
          TimeSlot(
            startsAt: DateTime(day.year, day.month, day.day, 8),
            status: firstSlotStatus,
          ),
          TimeSlot(
            startsAt: DateTime(day.year, day.month, day.day, 9),
            status: SlotStatus.busy,
          ),
          TimeSlot(
            startsAt: DateTime(day.year, day.month, day.day, 10),
            status: SlotStatus.closed,
          ),
        ],
      ),
      CourtDaySchedule(
        courtId: 'court-2',
        courtName: 'Quadra Coberta',
        hourlyPriceCents: 8000,
        slots: [
          TimeSlot(
            startsAt: DateTime(day.year, day.month, day.day, 8),
            status: SlotStatus.busy,
          ),
          TimeSlot(
            startsAt: DateTime(day.year, day.month, day.day, 9),
            status: SlotStatus.free,
          ),
          TimeSlot(
            startsAt: DateTime(day.year, day.month, day.day, 10),
            status: SlotStatus.free,
          ),
        ],
      ),
    ],
  );
}

/// Disponibilidade sem quadras para a data consultada.
DayAvailability emptyAvailability(DateTime day) {
  return DayAvailability(date: day, courts: const []);
}

/// Disponibilidade com quadras, mas sem horários livres.
DayAvailability unavailableAvailability(DateTime day) {
  final availability = sampleAvailability(day);

  return DayAvailability(
    date: day,
    courts: [
      for (final court in availability.courts)
        CourtDaySchedule(
          courtId: court.courtId,
          courtName: court.courtName,
          hourlyPriceCents: court.hourlyPriceCents,
          slots: [
            for (final slot in court.slots)
              TimeSlot(startsAt: slot.startsAt, status: SlotStatus.busy),
          ],
        ),
    ],
  );
}

/// Repositório controlado pelos testes.
class StubCourtsRepository implements CourtsRepository {
  /// Datas consultadas, na ordem das chamadas.
  final List<DateTime> fetchCalls = [];

  /// Permite configurar respostas, atrasos e falhas.
  Future<DayAvailability> Function(DateTime day)? fetchHandler;

  @override
  Future<DayAvailability> fetchAvailability(DateTime day) {
    fetchCalls.add(day);

    final handler = fetchHandler;

    if (handler != null) {
      return handler(day);
    }

    return Future.value(sampleAvailability(day));
  }

  @override
  Future<List<Court>> listCourts() async {
    throw UnimplementedError();
  }

  @override
  Future<List<Court>> listAllCourts() async {
    throw UnimplementedError();
  }

  @override
  Future<Court> createCourt(CourtInput input) async {
    throw UnimplementedError();
  }

  @override
  Future<Court> updateCourt(String id, CourtInput input) async {
    throw UnimplementedError();
  }
}

/// Substitui o repositório real e fixa o relógio.
List<Override> availabilityOverrides({
  required StubCourtsRepository repository,
}) {
  return [
    courtsRepositoryProvider.overrideWithValue(repository),
    clockProvider.overrideWithValue(() => testToday),
  ];
}

/// Inicializa o aplicativo na área pública,
/// utilizando uma janela de desktop e sem autenticação.
Future<void> pumpAvailabilityApp(
  WidgetTester tester, {
  required StubCourtsRepository repository,
}) async {
  tester.view.physicalSize = const Size(1400, 1200);
  tester.view.devicePixelRatio = 1;

  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final router = createAppRouter(
    initialLocation: AppRoutes.home,
    isLoggedIn: () => false,
  );

  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appRouterProvider.overrideWithValue(router),
        ...availabilityOverrides(repository: repository),
      ],
      child: const TennisHubApp(),
    ),
  );

  await tester.pump();
}
