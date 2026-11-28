import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tennishub/features/courts/domain/availability.dart';
import 'package:tennishub/features/courts/presentation/state/availability_controller.dart';
import 'package:tennishub/features/courts/presentation/widgets/availability_grid.dart';
import 'package:tennishub/features/courts/presentation/widgets/booking_summary.dart';

import '../../support/availability_test_support.dart';

/// Localiza o botão Continuar dentro do resumo da reserva.
Finder continueButton() {
  return find.descendant(
    of: find.byType(BookingSummary),
    matching: find.widgetWithText(FilledButton, 'Continuar'),
  );
}

/// Localiza exclusivamente a tabela de horários,
/// ignorando a legenda da grade.
Finder availabilityTable() {
  return find.descendant(
    of: find.byType(AvailabilityGrid),
    matching: find.byType(DataTable),
  );
}

/// Localiza os horários dentro da tabela,
/// sem considerar os textos da legenda.
Finder slotWithText(String label) {
  return find.descendant(of: availabilityTable(), matching: find.text(label));
}

/// Recupera o componente de resumo da reserva.
BookingSummary readSummary(WidgetTester tester) {
  return tester.widget<BookingSummary>(find.byType(BookingSummary));
}

/// Verifica se o botão Continuar está habilitado.
bool canContinue(WidgetTester tester) {
  expect(continueButton(), findsOneWidget);

  final button = tester.widget<FilledButton>(continueButton());

  return button.onPressed != null;
}

/// Abre a página pública utilizando o repositório falso.
Future<void> openPage(
  WidgetTester tester,
  StubCourtsRepository repository,
) async {
  await pumpAvailabilityApp(tester, repository: repository);

  await tester.pumpAndSettle();
}

/// Encerra a página e libera os recursos,
/// incluindo o temporizador de atualização.
Future<void> closePage(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

/// Seleciona o primeiro horário livre da tabela.
Future<void> selectFirstFreeSlot(WidgetTester tester) async {
  expect(availabilityTable(), findsOneWidget);
  expect(slotWithText('Livre'), findsWidgets);

  final slot = slotWithText('Livre').first;

  await tester.ensureVisible(slot);
  await tester.tap(slot);
  await tester.pumpAndSettle();

  final summary = readSummary(tester);

  expect(summary.court, isNotNull);
  expect(summary.slot, isNotNull);
  expect(summary.slot?.isFree, isTrue);

  expect(summary.court?.courtId, 'court-1');

  expect(
    summary.slot?.startsAt,
    DateTime(testToday.year, testToday.month, testToday.day, 8),
  );
}

void main() {
  late StubCourtsRepository repository;

  setUp(() {
    repository = StubCourtsRepository();
  });

  group('Consulta pública de disponibilidade', () {
    testWidgets('abre a área pública sem login', (tester) async {
      await openPage(tester, repository);

      expect(find.text('Reserve uma quadra'), findsOneWidget);

      expect(find.text('Área do proprietário'), findsOneWidget);

      expect(find.byType(AvailabilityGrid), findsOneWidget);

      expect(repository.fetchCalls, [testToday]);

      await closePage(tester);
    });

    testWidgets('exibe as quadras e os horários disponíveis', (tester) async {
      await openPage(tester, repository);

      expect(availabilityTable(), findsOneWidget);

      expect(find.text('Quadra 1'), findsWidgets);
      expect(find.text('Quadra Coberta'), findsWidgets);

      expect(find.text('08:00'), findsWidgets);
      expect(find.text('09:00'), findsWidgets);
      expect(find.text('10:00'), findsWidgets);

      expect(slotWithText('Livre'), findsWidgets);
      expect(slotWithText('Ocupado'), findsWidgets);
      expect(slotWithText('Fechado'), findsWidgets);

      await closePage(tester);
    });

    testWidgets('exibe carregamento enquanto aguarda os dados', (tester) async {
      final response = Completer<DayAvailability>();

      repository.fetchHandler = (_) => response.future;

      await pumpAvailabilityApp(tester, repository: repository);

      expect(find.text('Carregando horários...'), findsOneWidget);

      expect(find.byType(AvailabilityGrid), findsNothing);

      response.complete(sampleAvailability(testToday));

      await tester.pumpAndSettle();

      expect(find.text('Carregando horários...'), findsNothing);

      expect(find.byType(AvailabilityGrid), findsOneWidget);

      await closePage(tester);
    });
  });

  group('Seleção de horários', () {
    testWidgets('Continuar permanece desabilitado sem seleção', (tester) async {
      await openPage(tester, repository);

      final summary = readSummary(tester);

      expect(summary.court, isNull);
      expect(summary.slot, isNull);
      expect(canContinue(tester), isFalse);

      await closePage(tester);
    });

    testWidgets('permite selecionar um horário livre', (tester) async {
      await openPage(tester, repository);

      await selectFirstFreeSlot(tester);

      final summary = readSummary(tester);

      expect(summary.court?.courtName, 'Quadra 1');
      expect(summary.slot?.isFree, isTrue);
      expect(canContinue(tester), isTrue);

      expect(find.text('R\$ 60,00'), findsWidgets);

      await closePage(tester);
    });

    testWidgets('não permite selecionar um horário ocupado', (tester) async {
      await openPage(tester, repository);

      expect(slotWithText('Ocupado'), findsWidgets);

      final occupiedSlot = slotWithText('Ocupado').first;

      await tester.ensureVisible(occupiedSlot);
      await tester.tap(occupiedSlot);
      await tester.pumpAndSettle();

      final summary = readSummary(tester);

      expect(summary.court, isNull);
      expect(summary.slot, isNull);
      expect(canContinue(tester), isFalse);

      // Uma tentativa de selecionar um horário ocupado
      // também não deve substituir uma seleção válida.
      await selectFirstFreeSlot(tester);

      await tester.tap(occupiedSlot);
      await tester.pumpAndSettle();

      final selectedSummary = readSummary(tester);

      expect(selectedSummary.court?.courtId, 'court-1');
      expect(selectedSummary.slot?.isFree, isTrue);
      expect(selectedSummary.slot?.startsAt.hour, 8);

      await closePage(tester);
    });

    testWidgets('não permite selecionar um horário fechado', (tester) async {
      await openPage(tester, repository);

      expect(slotWithText('Fechado'), findsWidgets);

      final closedSlot = slotWithText('Fechado').first;

      await tester.ensureVisible(closedSlot);
      await tester.tap(closedSlot);
      await tester.pumpAndSettle();

      final summary = readSummary(tester);

      expect(summary.court, isNull);
      expect(summary.slot, isNull);
      expect(canContinue(tester), isFalse);

      // Um horário fechado não deve substituir
      // um horário livre já selecionado.
      await selectFirstFreeSlot(tester);

      await tester.tap(closedSlot);
      await tester.pumpAndSettle();

      final selectedSummary = readSummary(tester);

      expect(selectedSummary.court?.courtId, 'court-1');
      expect(selectedSummary.slot?.isFree, isTrue);
      expect(selectedSummary.slot?.startsAt.hour, 8);

      await closePage(tester);
    });

    testWidgets('Continuar apresenta os dados selecionados', (tester) async {
      await openPage(tester, repository);

      await selectFirstFreeSlot(tester);

      expect(canContinue(tester), isTrue);

      await tester.ensureVisible(continueButton());
      await tester.tap(continueButton());
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);

      expect(find.text('Horário selecionado'), findsOneWidget);

      expect(find.textContaining('Quadra: Quadra 1'), findsOneWidget);

      expect(find.textContaining('Data: 28/11/2026'), findsOneWidget);

      expect(find.textContaining('Horário: 08:00 - 09:00'), findsOneWidget);

      await tester.tap(find.text('Voltar'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);

      await closePage(tester);
    });
  });

  group('Estados de disponibilidade', () {
    testWidgets('exibe estado vazio quando não existem quadras', (
      tester,
    ) async {
      repository.fetchHandler = (day) async {
        return emptyAvailability(day);
      };

      await openPage(tester, repository);

      expect(find.text('Nenhum horário livre neste dia'), findsOneWidget);

      expect(find.text('Consultar próximo dia'), findsOneWidget);

      expect(find.byType(AvailabilityGrid), findsNothing);

      await closePage(tester);
    });

    testWidgets('exibe estado vazio quando todos os horários estão ocupados', (
      tester,
    ) async {
      repository.fetchHandler = (day) async {
        return unavailableAvailability(day);
      };

      await openPage(tester, repository);

      expect(find.text('Nenhum horário livre neste dia'), findsOneWidget);

      expect(find.byType(AvailabilityGrid), findsNothing);

      await closePage(tester);
    });

    testWidgets('permite consultar o próximo dia no estado vazio', (
      tester,
    ) async {
      repository.fetchHandler = (day) async {
        if (day == testToday) {
          return emptyAvailability(day);
        }

        return sampleAvailability(day);
      };

      await openPage(tester, repository);

      final nextDayButton = find.text('Consultar próximo dia');

      await tester.ensureVisible(nextDayButton);
      await tester.tap(nextDayButton);
      await tester.pumpAndSettle();

      final tomorrow = DateTime(
        testToday.year,
        testToday.month,
        testToday.day + 1,
      );

      expect(repository.fetchCalls, [testToday, tomorrow]);

      expect(find.byType(AvailabilityGrid), findsOneWidget);

      expect(find.text('Nenhum horário livre neste dia'), findsNothing);

      await closePage(tester);
    });

    testWidgets('exibe erro quando a consulta falha', (tester) async {
      repository.fetchHandler = (_) async {
        throw Exception('Falha de conexão');
      };

      await openPage(tester, repository);

      expect(
        find.text('Não foi possível carregar os horários'),
        findsOneWidget,
      );

      expect(find.text('Tentar novamente'), findsOneWidget);

      expect(find.byType(AvailabilityGrid), findsNothing);

      await closePage(tester);
    });

    testWidgets('permite tentar novamente após uma falha', (tester) async {
      repository.fetchHandler = (_) async {
        throw Exception('Falha de conexão');
      };

      await openPage(tester, repository);

      repository.fetchHandler = null;

      final retryButton = find.text('Tentar novamente');

      await tester.ensureVisible(retryButton);
      await tester.tap(retryButton);
      await tester.pumpAndSettle();

      expect(repository.fetchCalls, hasLength(2));

      expect(find.byType(AvailabilityGrid), findsOneWidget);

      expect(find.text('Não foi possível carregar os horários'), findsNothing);

      await closePage(tester);
    });
  });

  group('Atualização automática', () {
    testWidgets('consulta novamente após o intervalo de atualização', (
      tester,
    ) async {
      await openPage(tester, repository);

      expect(repository.fetchCalls, hasLength(1));

      await tester.pump(AvailabilityController.refreshInterval);

      await tester.pumpAndSettle();

      expect(repository.fetchCalls, hasLength(2));

      expect(find.byType(AvailabilityGrid), findsOneWidget);

      await closePage(tester);
    });

    testWidgets('preserva a grade e a seleção durante a atualização', (
      tester,
    ) async {
      await openPage(tester, repository);

      await selectFirstFreeSlot(tester);

      final previousSummary = readSummary(tester);

      expect(previousSummary.court, isNotNull);
      expect(previousSummary.slot, isNotNull);

      final response = Completer<DayAvailability>();

      repository.fetchHandler = (_) => response.future;

      await tester.pump(AvailabilityController.refreshInterval);

      await tester.pump();

      expect(repository.fetchCalls, hasLength(2));

      expect(find.byType(AvailabilityGrid), findsOneWidget);

      expect(find.text('Atualizando horários...'), findsOneWidget);

      final refreshingSummary = readSummary(tester);

      expect(refreshingSummary.court?.courtId, previousSummary.court?.courtId);

      expect(refreshingSummary.slot?.startsAt, previousSummary.slot?.startsAt);

      response.complete(sampleAvailability(testToday));

      await tester.pumpAndSettle();

      final updatedSummary = readSummary(tester);

      expect(updatedSummary.court?.courtId, previousSummary.court?.courtId);

      expect(updatedSummary.slot?.startsAt, previousSummary.slot?.startsAt);

      expect(updatedSummary.slot?.isFree, isTrue);
      expect(canContinue(tester), isTrue);

      await closePage(tester);
    });

    testWidgets('remove a seleção quando o horário se torna ocupado', (
      tester,
    ) async {
      await openPage(tester, repository);

      await selectFirstFreeSlot(tester);

      final previousSummary = readSummary(tester);

      expect(previousSummary.slot, isNotNull);
      expect(previousSummary.slot?.isFree, isTrue);

      repository.fetchHandler = (day) async {
        return sampleAvailability(day, firstSlotStatus: SlotStatus.busy);
      };

      await tester.pump(AvailabilityController.refreshInterval);

      await tester.pumpAndSettle();

      expect(repository.fetchCalls, hasLength(2));

      final summary = readSummary(tester);

      expect(summary.court, isNull);
      expect(summary.slot, isNull);
      expect(canContinue(tester), isFalse);

      expect(
        find.textContaining('O horário selecionado não está mais disponível'),
        findsOneWidget,
      );

      expect(find.byType(AvailabilityGrid), findsOneWidget);

      await closePage(tester);
    });
  });
}
