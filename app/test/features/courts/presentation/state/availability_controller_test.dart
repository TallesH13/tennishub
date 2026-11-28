import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tennishub/features/courts/domain/availability.dart';
import 'package:tennishub/features/courts/presentation/state/availability_controller.dart';
import 'package:tennishub/features/courts/presentation/state/availability_state.dart';

import '../../support/availability_test_support.dart';

void main() {
  late StubCourtsRepository repository;
  late ProviderContainer container;
  late AvailabilityController controller;

  AvailabilityState readState() {
    return container.read(availabilityControllerProvider);
  }

  setUp(() {
    repository = StubCourtsRepository();

    container = ProviderContainer(
      overrides: availabilityOverrides(repository: repository),
    );

    // Mantém o provider ativo durante cada teste.
    container.listen(availabilityControllerProvider, (_, _) {});

    controller = container.read(availabilityControllerProvider.notifier);
  });

  tearDown(() {
    container.dispose();
  });

  group('Estado inicial', () {
    test('inicia com a data de hoje', () {
      expect(readState().selectedDate, testToday);
      expect(readState().status, AvailabilityStatus.initial);
      expect(readState().availability, isNull);
      expect(readState().isRefreshing, isFalse);
      expect(repository.fetchCalls, isEmpty);
    });

    test('define o limite de consulta em 30 dias', () {
      expect(
        controller.lastAllowedDate,
        DateTime(testToday.year, testToday.month, testToday.day + 30),
      );
    });
  });

  group('Consulta de disponibilidade', () {
    test('exibe carregamento enquanto aguarda o repositório', () async {
      final response = Completer<DayAvailability>();

      repository.fetchHandler = (_) => response.future;

      final request = controller.loadAvailability();

      expect(readState().status, AvailabilityStatus.loading);
      expect(readState().isLoading, isTrue);

      response.complete(sampleAvailability(testToday));

      await request;

      expect(readState().status, AvailabilityStatus.success);
      expect(readState().isLoading, isFalse);
    });

    test('carrega as quadras e os horários disponíveis', () async {
      await controller.loadAvailability();

      final state = readState();

      expect(state.status, AvailabilityStatus.success);
      expect(state.availability?.courts, hasLength(2));
      expect(state.hasFreeSlots, isTrue);
      expect(state.lastUpdatedAt, testToday);
      expect(repository.fetchCalls, [testToday]);

      final firstCourt = state.availability!.courts.first;

      expect(firstCourt.courtName, 'Quadra 1');
      expect(firstCourt.slots, hasLength(3));
      expect(firstCourt.slots[0].status, SlotStatus.free);
      expect(firstCourt.slots[1].status, SlotStatus.busy);
      expect(firstCourt.slots[2].status, SlotStatus.closed);

      for (final slot in firstCourt.slots) {
        expect(slot.endsAt.difference(slot.startsAt), const Duration(hours: 1));
      }
    });

    test('identifica quando não existem quadras', () async {
      repository.fetchHandler = (day) async {
        return emptyAvailability(day);
      };

      await controller.loadAvailability();

      expect(readState().status, AvailabilityStatus.success);
      expect(readState().availability?.courts, isEmpty);
      expect(readState().hasFreeSlots, isFalse);
    });

    test('identifica quando não existem horários livres', () async {
      repository.fetchHandler = (day) async {
        return unavailableAvailability(day);
      };

      await controller.loadAvailability();

      expect(readState().status, AvailabilityStatus.success);
      expect(readState().availability?.courts, hasLength(2));
      expect(readState().hasFreeSlots, isFalse);
    });

    test('registra uma falha na consulta', () async {
      repository.fetchHandler = (_) async {
        throw Exception('Falha de conexão');
      };

      await controller.loadAvailability();

      expect(readState().status, AvailabilityStatus.failure);
      expect(readState().hasError, isTrue);
      expect(readState().errorMessage, 'Não foi possível carregar os horários');
    });

    test('permite repetir uma consulta após uma falha', () async {
      repository.fetchHandler = (_) async {
        throw Exception('Falha de conexão');
      };

      await controller.loadAvailability();

      expect(readState().hasError, isTrue);

      repository.fetchHandler = null;

      await controller.loadAvailability();

      expect(readState().status, AvailabilityStatus.success);
      expect(readState().errorMessage, isNull);
      expect(readState().hasFreeSlots, isTrue);
      expect(repository.fetchCalls, hasLength(2));
    });
  });

  group('Seleção de datas', () {
    test('permite selecionar uma data futura válida', () async {
      final tomorrow = DateTime(
        testToday.year,
        testToday.month,
        testToday.day + 1,
      );

      await controller.selectDate(tomorrow);

      expect(readState().selectedDate, tomorrow);
      expect(readState().availability?.date, tomorrow);
      expect(repository.fetchCalls, [tomorrow]);
    });

    test('não permite selecionar uma data passada', () async {
      final yesterday = DateTime(
        testToday.year,
        testToday.month,
        testToday.day - 1,
      );

      await controller.selectDate(yesterday);

      expect(readState().selectedDate, testToday);
      expect(repository.fetchCalls, isEmpty);
    });

    test('permite selecionar exatamente 30 dias à frente', () async {
      final lastDay = controller.lastAllowedDate;

      await controller.selectDate(lastDay);

      expect(readState().selectedDate, lastDay);
      expect(readState().status, AvailabilityStatus.success);
      expect(repository.fetchCalls, [lastDay]);
    });

    test('não permite selecionar uma data além de 30 dias', () async {
      final invalidDate = DateTime(
        testToday.year,
        testToday.month,
        testToday.day + 31,
      );

      await controller.selectDate(invalidDate);

      expect(readState().selectedDate, testToday);
      expect(repository.fetchCalls, isEmpty);
    });
  });

  group('Atualização da disponibilidade', () {
    test('preserva os dados enquanto atualiza os horários', () async {
      await controller.loadAvailability();

      final previousAvailability = readState().availability;
      final response = Completer<DayAvailability>();

      repository.fetchHandler = (_) => response.future;

      final request = controller.refreshAvailability();

      expect(readState().isRefreshing, isTrue);
      expect(readState().status, AvailabilityStatus.success);
      expect(readState().availability, same(previousAvailability));
      expect(readState().selectedDate, testToday);

      response.complete(sampleAvailability(testToday));

      await request;

      expect(readState().isRefreshing, isFalse);
      expect(readState().status, AvailabilityStatus.success);
      expect(repository.fetchCalls, hasLength(2));
    });

    test('atualiza um horário que deixou de estar livre', () async {
      await controller.loadAvailability();

      expect(readState().availability!.courts.first.slots.first.isFree, isTrue);

      repository.fetchHandler = (day) async {
        return sampleAvailability(day, firstSlotStatus: SlotStatus.busy);
      };

      await controller.refreshAvailability();

      expect(
        readState().availability!.courts.first.slots.first.status,
        SlotStatus.busy,
      );

      expect(readState().status, AvailabilityStatus.success);
      expect(readState().isRefreshing, isFalse);
    });

    test('preserva os dados quando uma atualização falha', () async {
      await controller.loadAvailability();

      final previousAvailability = readState().availability;

      repository.fetchHandler = (_) async {
        throw Exception('Falha na atualização');
      };

      await controller.refreshAvailability();

      expect(readState().status, AvailabilityStatus.success);
      expect(readState().availability, same(previousAvailability));
      expect(readState().isRefreshing, isFalse);
      expect(
        readState().errorMessage,
        'Não foi possível atualizar os horários',
      );
    });

    test('remove o erro após uma atualização bem-sucedida', () async {
      await controller.loadAvailability();

      repository.fetchHandler = (_) async {
        throw Exception('Falha na atualização');
      };

      await controller.refreshAvailability();

      expect(readState().errorMessage, isNotNull);

      repository.fetchHandler = null;

      await controller.refreshAvailability();

      expect(readState().errorMessage, isNull);
      expect(readState().status, AvailabilityStatus.success);
    });

    test('não executa duas atualizações simultâneas', () async {
      await controller.loadAvailability();

      final response = Completer<DayAvailability>();

      repository.fetchHandler = (_) => response.future;

      final firstRequest = controller.refreshAvailability();

      await controller.refreshAvailability();

      expect(repository.fetchCalls, hasLength(2));

      response.complete(sampleAvailability(testToday));

      await firstRequest;

      expect(readState().isRefreshing, isFalse);
    });
  });

  group('Concorrência de consultas', () {
    test('ignora respostas antigas ao trocar de data', () async {
      final firstDay = testToday;

      final secondDay = DateTime(
        testToday.year,
        testToday.month,
        testToday.day + 1,
      );

      final firstResponse = Completer<DayAvailability>();
      final secondResponse = Completer<DayAvailability>();

      repository.fetchHandler = (day) {
        return day == firstDay ? firstResponse.future : secondResponse.future;
      };

      final firstRequest = controller.loadAvailability();

      final secondRequest = controller.selectDate(secondDay);

      secondResponse.complete(sampleAvailability(secondDay));

      await secondRequest;

      firstResponse.complete(sampleAvailability(firstDay));

      await firstRequest;

      expect(readState().selectedDate, secondDay);
      expect(readState().availability?.date, secondDay);
      expect(readState().status, AvailabilityStatus.success);
    });
  });
}
