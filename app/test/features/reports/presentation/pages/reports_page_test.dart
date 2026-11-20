import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tennishub/core/router/app_routes.dart';
import 'package:tennishub/features/reports/domain/rental_report.dart';
import 'package:tennishub/features/reports/domain/report_filter.dart';
import 'package:tennishub/features/reports/domain/reports_repository.dart';
import 'package:tennishub/features/reports/presentation/widgets/report_filter_form.dart';
import 'package:tennishub/features/reports/presentation/widgets/report_result_section.dart';
import 'package:tennishub/features/reports/presentation/widgets/report_totals_view.dart';

import '../../support/report_test_support.dart';

/// Toca em "Gerar relatório" e espera a tela estabilizar.
Future<void> generate(WidgetTester tester) async {
  await tester.tap(find.byKey(ReportFilterKeys.submit));
  await tester.pumpAndSettle();
}

/// Digita nos campos de data (a máscara coloca as barras).
Future<void> typePeriod(
  WidgetTester tester, {
  required String from,
  required String to,
}) async {
  await tester.enterText(find.byKey(ReportFilterKeys.from), from);
  await tester.enterText(find.byKey(ReportFilterKeys.to), to);
  await tester.pump();
}

/// Texto digitado hoje em um campo do formulário.
String fieldText(WidgetTester tester, Key key) {
  return tester.widget<TextFormField>(find.byKey(key)).controller!.text;
}

/// Procura o texto [text] dentro do cartão de total identificado por [key].
Finder inTotal(Key key, String text) {
  return find.descendant(of: find.byKey(key), matching: find.text(text));
}

Future<void> chooseCourt(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(ReportFilterKeys.court));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

void main() {
  group('abertura', () {
    testWidgets('abre com o período do mês atual e sem resultado', (
      tester,
    ) async {
      final repository = StubReportsRepository();
      await pumpReportsApp(tester, repository: repository);

      expect(find.text('Relatório de locações'), findsOneWidget);
      expect(fieldText(tester, ReportFilterKeys.from), '01/11/2026');
      expect(fieldText(tester, ReportFilterKeys.to), '30/11/2026');
      expect(
        find.text('Escolha o período e toque em "Gerar relatório".'),
        findsOneWidget,
      );
      expect(repository.fetchCalls, isEmpty);
      expect(find.byKey(ReportResultKeys.export), findsNothing);
    });

    testWidgets('o painel do proprietário leva ao relatório e volta', (
      tester,
    ) async {
      await pumpReportsApp(
        tester,
        repository: StubReportsRepository(),
        location: AppRoutes.admin,
      );

      await tester.tap(find.text('Relatório de locações'));
      await tester.pumpAndSettle();

      expect(find.byKey(ReportFilterKeys.submit), findsOneWidget);

      await tester.tap(find.text('Painel do proprietário'));
      await tester.pumpAndSettle();

      expect(find.text('Em construção: login e painel.'), findsOneWidget);
    });

    testWidgets('as datas aceitam só dígitos e ganham as barras sozinhas', (
      tester,
    ) async {
      await pumpReportsApp(tester, repository: StubReportsRepository());

      await tester.enterText(find.byKey(ReportFilterKeys.from), '01102026');
      await tester.pump();

      expect(fieldText(tester, ReportFilterKeys.from), '01/10/2026');
    });
  });

  group('gerar o relatório', () {
    testWidgets('mostra a tabela de locações com os clientes identificados', (
      tester,
    ) async {
      await pumpReportsApp(tester, repository: StubReportsRepository());

      await generate(tester);

      expect(find.text('Ana Paula Souza'), findsOneWidget);
      expect(find.text('(31) 99999-0001'), findsOneWidget);
      expect(find.text('03/11/2026 08:00'), findsOneWidget);
      expect(find.text('R\$ 60,00'), findsWidgets);
      expect(find.text('Bruno Henrique Lima'), findsOneWidget);
      expect(find.text('Carla Mendes Ribeiro'), findsOneWidget);
      expect(find.text('(31) 99999-0003'), findsOneWidget);
    });

    testWidgets('mostra os totais: locações, horas e valor', (tester) async {
      await pumpReportsApp(tester, repository: StubReportsRepository());

      await generate(tester);

      expect(inTotal(ReportTotalsKeys.count, '3'), findsOneWidget);
      expect(inTotal(ReportTotalsKeys.hours, '3 h'), findsOneWidget);
      expect(inTotal(ReportTotalsKeys.value, 'R\$ 140,00'), findsOneWidget);
    });

    testWidgets('mostra os totais por quadra', (tester) async {
      await pumpReportsApp(tester, repository: StubReportsRepository());

      await generate(tester);

      expect(find.text('Por quadra'), findsOneWidget);
      // Cada quadra aparece na tabela de locações e na de totais.
      expect(find.text('Quadra 1'), findsNWidgets(2));
      expect(find.text('Quadra Coberta'), findsNWidgets(2));
    });

    testWidgets('quadra sem valor por hora mostra traço no lugar do valor', (
      tester,
    ) async {
      await pumpReportsApp(
        tester,
        repository: StubReportsRepository(rentals: [sampleRentals().last]),
      );

      await generate(tester);

      expect(inTotal(ReportTotalsKeys.value, '—'), findsOneWidget);
      expect(find.text('Nenhuma quadra com valor por hora'), findsOneWidget);
    });

    testWidgets('envia o período digitado ao repositório', (tester) async {
      final repository = StubReportsRepository();
      await pumpReportsApp(tester, repository: repository);

      await typePeriod(tester, from: '01102026', to: '15102026');
      await generate(tester);

      expect(repository.fetchCalls, hasLength(1));
      expect(repository.fetchCalls.single.from, DateTime(2026, 10, 1));
      expect(repository.fetchCalls.single.to, DateTime(2026, 10, 15));
    });

    testWidgets('envia cliente e quadra escolhidos', (tester) async {
      final repository = StubReportsRepository();
      await pumpReportsApp(tester, repository: repository);

      await tester.enterText(find.byKey(ReportFilterKeys.client), '  ana ');
      await chooseCourt(tester, 'Quadra Coberta');
      await generate(tester);

      final filter = repository.fetchCalls.single;
      expect(filter.client, 'ana');
      expect(filter.courtId, 'court-3');
    });

    testWidgets('sem cliente nem quadra, não envia esses filtros', (
      tester,
    ) async {
      final repository = StubReportsRepository();
      await pumpReportsApp(tester, repository: repository);

      await generate(tester);

      final filter = repository.fetchCalls.single;
      expect(filter.client, isNull);
      expect(filter.courtId, isNull);
    });

    testWidgets('gerar de novo troca o resultado', (tester) async {
      final repository = StubReportsRepository();
      await pumpReportsApp(tester, repository: repository);
      await generate(tester);
      expect(find.text('Carla Mendes Ribeiro'), findsOneWidget);

      repository.fetchHandler = (_) async =>
          RentalReport.fromRentals([sampleRentals().first]);
      await generate(tester);

      expect(find.text('Carla Mendes Ribeiro'), findsNothing);
      expect(inTotal(ReportTotalsKeys.count, '1'), findsOneWidget);
    });
  });

  group('validação do período', () {
    testWidgets('data final anterior à inicial mostra erro e não busca', (
      tester,
    ) async {
      final repository = StubReportsRepository();
      await pumpReportsApp(tester, repository: repository);

      await typePeriod(tester, from: '30112026', to: '01112026');
      await generate(tester);

      expect(
        find.text('A data final não pode ser anterior à inicial.'),
        findsOneWidget,
      );
      expect(repository.fetchCalls, isEmpty);
    });

    testWidgets('período maior que 1 ano mostra erro e não busca', (
      tester,
    ) async {
      final repository = StubReportsRepository();
      await pumpReportsApp(tester, repository: repository);

      await typePeriod(tester, from: '01012024', to: '01012026');
      await generate(tester);

      expect(find.text('O período não pode passar de 1 ano.'), findsOneWidget);
      expect(repository.fetchCalls, isEmpty);
    });

    testWidgets('data que não existe mostra erro', (tester) async {
      final repository = StubReportsRepository();
      await pumpReportsApp(tester, repository: repository);

      await typePeriod(tester, from: '31022026', to: '30112026');
      await generate(tester);

      expect(find.text('Data inválida. Use dd/mm/aaaa.'), findsOneWidget);
      expect(repository.fetchCalls, isEmpty);
    });

    testWidgets('datas em branco pedem o preenchimento', (tester) async {
      final repository = StubReportsRepository();
      await pumpReportsApp(tester, repository: repository);

      await typePeriod(tester, from: '', to: '');
      await generate(tester);

      expect(find.text('Informe a data inicial.'), findsOneWidget);
      expect(find.text('Informe a data final.'), findsOneWidget);
      expect(repository.fetchCalls, isEmpty);
    });

    testWidgets('o erro some quando o período é corrigido', (tester) async {
      final repository = StubReportsRepository();
      await pumpReportsApp(tester, repository: repository);
      await typePeriod(tester, from: '30112026', to: '01112026');
      await generate(tester);

      await typePeriod(tester, from: '01112026', to: '30112026');
      await generate(tester);

      expect(
        find.text('A data final não pode ser anterior à inicial.'),
        findsNothing,
      );
      expect(repository.fetchCalls, hasLength(1));
    });

    testWidgets('período de um dia só (início igual ao fim) é aceito', (
      tester,
    ) async {
      final repository = StubReportsRepository();
      await pumpReportsApp(tester, repository: repository);

      await typePeriod(tester, from: '10112026', to: '10112026');
      await generate(tester);

      expect(repository.fetchCalls, hasLength(1));
    });
  });

  group('atalhos de período', () {
    testWidgets('"Este mês" preenche o mês atual', (tester) async {
      await pumpReportsApp(tester, repository: StubReportsRepository());
      await typePeriod(tester, from: '01012026', to: '31012026');

      await tester.tap(find.text('Este mês'));
      await tester.pump();

      expect(fieldText(tester, ReportFilterKeys.from), '01/11/2026');
      expect(fieldText(tester, ReportFilterKeys.to), '30/11/2026');
    });

    testWidgets('"Mês passado" preenche o mês anterior', (tester) async {
      await pumpReportsApp(tester, repository: StubReportsRepository());

      await tester.tap(find.text('Mês passado'));
      await tester.pump();

      expect(fieldText(tester, ReportFilterKeys.from), '01/10/2026');
      expect(fieldText(tester, ReportFilterKeys.to), '31/10/2026');
    });

    testWidgets('o atalho vale na hora de gerar o relatório', (tester) async {
      final repository = StubReportsRepository();
      await pumpReportsApp(tester, repository: repository);

      await tester.tap(find.text('Mês passado'));
      await tester.pump();
      await generate(tester);

      expect(repository.fetchCalls.single.from, DateTime(2026, 10, 1));
      expect(repository.fetchCalls.single.to, DateTime(2026, 10, 31));
    });
  });

  group('estados da tela', () {
    testWidgets('período sem locações mostra estado vazio e totais zerados', (
      tester,
    ) async {
      await pumpReportsApp(
        tester,
        repository: StubReportsRepository(rentals: const []),
      );

      await generate(tester);

      expect(
        find.text('Nenhuma locação encontrada no período.'),
        findsOneWidget,
      );
      expect(inTotal(ReportTotalsKeys.count, '0'), findsOneWidget);
      expect(inTotal(ReportTotalsKeys.hours, '0 h'), findsOneWidget);
      expect(inTotal(ReportTotalsKeys.value, '—'), findsOneWidget);
      expect(find.byType(DataTable), findsNothing);
    });

    testWidgets('mostra carregando enquanto busca e bloqueia novo pedido', (
      tester,
    ) async {
      final repository = StubReportsRepository();
      final gate = Completer<RentalReport>();
      repository.fetchHandler = (_) => gate.future;
      await pumpReportsApp(tester, repository: repository);

      await tester.tap(find.byKey(ReportFilterKeys.submit));
      await tester.pump();

      expect(find.text('Gerando o relatório...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.byKey(ReportFilterKeys.submit),
      );
      expect(button.onPressed, isNull);

      gate.complete(RentalReport.fromRentals(sampleRentals()));
      await tester.pumpAndSettle();

      expect(find.text('Gerando o relatório...'), findsNothing);
      expect(find.text('Ana Paula Souza'), findsOneWidget);
    });

    testWidgets('erro mostra a mensagem e "Tentar novamente" refaz a busca', (
      tester,
    ) async {
      final repository = StubReportsRepository();
      repository.fetchHandler = (_) =>
          Future.error(const ReportsException('Falha ao consultar a API.'));
      await pumpReportsApp(tester, repository: repository);
      await generate(tester);

      expect(find.text('Falha ao consultar a API.'), findsOneWidget);
      expect(find.byKey(ReportResultKeys.retry), findsOneWidget);

      repository.fetchHandler = null;
      await tester.tap(find.byKey(ReportResultKeys.retry));
      await tester.pumpAndSettle();

      expect(find.text('Falha ao consultar a API.'), findsNothing);
      expect(find.text('Ana Paula Souza'), findsOneWidget);
      expect(repository.fetchCalls, hasLength(2));
      expect(repository.fetchCalls.first, repository.fetchCalls.last);
    });

    testWidgets('erro inesperado mostra mensagem sem detalhes técnicos', (
      tester,
    ) async {
      final repository = StubReportsRepository();
      repository.fetchHandler = (_) =>
          Future.error(Exception('stack trace interno'));
      await pumpReportsApp(tester, repository: repository);

      await generate(tester);

      expect(find.textContaining('stack trace interno'), findsNothing);
      expect(
        find.text('Não foi possível gerar o relatório. Tente novamente.'),
        findsOneWidget,
      );
    });
  });

  group('exportar PDF', () {
    testWidgets('o botão só aparece depois de gerar o relatório', (
      tester,
    ) async {
      await pumpReportsApp(tester, repository: StubReportsRepository());
      expect(find.byKey(ReportResultKeys.export), findsNothing);

      await generate(tester);

      expect(find.byKey(ReportResultKeys.export), findsOneWidget);
    });

    testWidgets('baixa o PDF do mesmo relatório e avisa o nome do arquivo', (
      tester,
    ) async {
      final repository = StubReportsRepository();
      final saver = RecordingReportFileSaver();
      await pumpReportsApp(tester, repository: repository, saver: saver);
      await typePeriod(tester, from: '01102026', to: '15102026');
      await generate(tester);

      await tester.tap(find.byKey(ReportResultKeys.export));
      await tester.pumpAndSettle();

      expect(repository.exportCalls.single, repository.fetchCalls.single);
      expect(saver.saved.single.fileName, 'relatorio-teste.pdf');
      expect(find.text('PDF gerado: relatorio-teste.pdf'), findsOneWidget);
    });

    testWidgets(
      'usa os filtros do relatório exibido, não o que foi editado depois',
      (tester) async {
        final repository = StubReportsRepository();
        await pumpReportsApp(tester, repository: repository);
        await generate(tester);

        await tester.enterText(find.byKey(ReportFilterKeys.client), 'Bruno');
        await typePeriod(tester, from: '01012026', to: '31012026');
        await tester.tap(find.byKey(ReportResultKeys.export));
        await tester.pumpAndSettle();

        final exported = repository.exportCalls.single;
        expect(exported.client, isNull);
        expect(exported.from, DateTime(2026, 11, 1));
        expect(exported.to, DateTime(2026, 11, 30));
      },
    );

    testWidgets('falha ao baixar mostra a mensagem do erro', (tester) async {
      final saver = RecordingReportFileSaver()
        ..error = const ReportsException('Não foi possível baixar o PDF.');
      await pumpReportsApp(
        tester,
        repository: StubReportsRepository(),
        saver: saver,
      );
      await generate(tester);

      await tester.tap(find.byKey(ReportResultKeys.export));
      await tester.pumpAndSettle();

      expect(find.text('Não foi possível baixar o PDF.'), findsOneWidget);
      expect(find.textContaining('PDF gerado'), findsNothing);
    });

    testWidgets('falha ao gerar o PDF mostra mensagem e libera o botão', (
      tester,
    ) async {
      final repository = StubReportsRepository();
      repository.exportHandler = (_) =>
          Future.error(const ReportsException('A API não respondeu.'));
      await pumpReportsApp(tester, repository: repository);
      await generate(tester);

      await tester.tap(find.byKey(ReportResultKeys.export));
      await tester.pumpAndSettle();

      expect(find.text('A API não respondeu.'), findsOneWidget);
      final button = tester.widget<OutlinedButton>(
        find.byKey(ReportResultKeys.export),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('o botão fica desabilitado enquanto o PDF é gerado', (
      tester,
    ) async {
      final repository = StubReportsRepository();
      final gate = Completer<void>();
      repository.exportHandler = (_) async {
        await gate.future;
        return sampleReportFile();
      };
      await pumpReportsApp(tester, repository: repository);
      await generate(tester);

      await tester.tap(find.byKey(ReportResultKeys.export));
      await tester.pump();

      final button = tester.widget<OutlinedButton>(
        find.byKey(ReportResultKeys.export),
      );
      expect(button.onPressed, isNull);

      gate.complete();
      await tester.pumpAndSettle();

      expect(repository.exportCalls, hasLength(1));
    });

    testWidgets('relatório vazio também pode ser exportado', (tester) async {
      final repository = StubReportsRepository(rentals: const []);
      await pumpReportsApp(tester, repository: repository);
      await generate(tester);

      await tester.tap(find.byKey(ReportResultKeys.export));
      await tester.pumpAndSettle();

      expect(repository.exportCalls, hasLength(1));
    });
  });

  group('filtros', () {
    testWidgets('a lista de quadras vem do repositório', (tester) async {
      await pumpReportsApp(tester, repository: StubReportsRepository());

      await tester.tap(find.byKey(ReportFilterKeys.court));
      await tester.pumpAndSettle();

      expect(find.text('Todas as quadras'), findsWidgets);
      for (final court in sampleCourts) {
        expect(find.text(court.name), findsWidgets);
      }
    });

    testWidgets('o filtro enviado respeita períodos de mês passado', (
      tester,
    ) async {
      final repository = StubReportsRepository();
      await pumpReportsApp(tester, repository: repository);

      await tester.tap(find.text('Mês passado'));
      await tester.pump();
      await chooseCourt(tester, 'Quadra 1');
      await generate(tester);

      expect(
        repository.fetchCalls.single,
        ReportFilter(
          from: DateTime(2026, 10, 1),
          to: DateTime(2026, 10, 31),
          courtId: 'court-1',
        ),
      );
    });
  });
}
