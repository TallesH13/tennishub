import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tennishub/features/reports/domain/rental_report.dart';
import 'package:tennishub/features/reports/domain/report_filter.dart';
import 'package:tennishub/features/reports/domain/reports_repository.dart';
import 'package:tennishub/features/reports/presentation/state/reports_controller.dart';
import 'package:tennishub/features/reports/presentation/state/reports_state.dart';

import '../../support/report_test_support.dart';

ReportFilter novemberFilter() {
  return ReportFilter(from: DateTime(2026, 11, 1), to: DateTime(2026, 11, 30));
}

({
  ProviderContainer container,
  StubReportsRepository repository,
  RecordingReportFileSaver saver,
})
setUpController() {
  final repository = StubReportsRepository();
  final saver = RecordingReportFileSaver();
  final container = ProviderContainer(
    overrides: reportOverrides(repository: repository, saver: saver),
  );
  addTearDown(container.dispose);
  // Mantém o estado vivo (o provider descarta sozinho sem ouvintes).
  container.listen(reportsControllerProvider, (_, _) {});
  return (container: container, repository: repository, saver: saver);
}

void main() {
  group('estado inicial', () {
    test('começa sem relatório e com o filtro do mês atual', () {
      final setup = setUpController();

      final state = setup.container.read(reportsControllerProvider);

      expect(state.status, ReportStatus.initial);
      expect(state.report, isNull);
      expect(state.filter.from, DateTime(2026, 11, 1));
      expect(state.filter.to, DateTime(2026, 11, 30));
      expect(state.isExporting, isFalse);
    });
  });

  group('generate', () {
    test('busca o relatório e guarda o resultado e o filtro usado', () async {
      final setup = setUpController();
      final controller = setup.container.read(
        reportsControllerProvider.notifier,
      );

      await controller.generate(novemberFilter());

      final state = setup.container.read(reportsControllerProvider);
      expect(state.status, ReportStatus.success);
      expect(state.report!.totals.count, 3);
      expect(state.appliedFilter, novemberFilter());
      expect(setup.repository.fetchCalls, [novemberFilter()]);
    });

    test('passa pelo estado de carregando', () async {
      final setup = setUpController();
      final gate = Completer<RentalReport>();
      setup.repository.fetchHandler = (_) => gate.future;
      final controller = setup.container.read(
        reportsControllerProvider.notifier,
      );

      final future = controller.generate(novemberFilter());
      expect(
        setup.container.read(reportsControllerProvider).status,
        ReportStatus.loading,
      );

      gate.complete(RentalReport.fromRentals(const []));
      await future;

      expect(
        setup.container.read(reportsControllerProvider).status,
        ReportStatus.success,
      );
    });

    test('período inválido não chama o repositório', () async {
      final setup = setUpController();
      final controller = setup.container.read(
        reportsControllerProvider.notifier,
      );
      final invalid = ReportFilter(
        from: DateTime(2026, 11, 30),
        to: DateTime(2026, 11, 1),
      );

      await controller.generate(invalid);

      expect(setup.repository.fetchCalls, isEmpty);
      expect(
        setup.container.read(reportsControllerProvider).status,
        ReportStatus.initial,
      );
    });

    test('erro do repositório mostra a mensagem dele', () async {
      final setup = setUpController();
      setup.repository.fetchHandler = (_) =>
          Future.error(const ReportsException('Sem conexão com a API.'));
      final controller = setup.container.read(
        reportsControllerProvider.notifier,
      );

      await controller.generate(novemberFilter());

      final state = setup.container.read(reportsControllerProvider);
      expect(state.status, ReportStatus.failure);
      expect(state.errorMessage, 'Sem conexão com a API.');
      expect(state.report, isNull);
    });

    test('erro inesperado mostra uma mensagem genérica', () async {
      final setup = setUpController();
      setup.repository.fetchHandler = (_) =>
          Future.error(Exception('detalhe técnico'));
      final controller = setup.container.read(
        reportsControllerProvider.notifier,
      );

      await controller.generate(novemberFilter());

      final state = setup.container.read(reportsControllerProvider);
      expect(state.status, ReportStatus.failure);
      expect(state.errorMessage, isNot(contains('detalhe técnico')));
      expect(state.errorMessage, contains('Tente novamente'));
    });

    test(
      'gerar de novo depois de um erro volta a mostrar o resultado',
      () async {
        final setup = setUpController();
        setup.repository.fetchHandler = (_) =>
            Future.error(const ReportsException('Falhou.'));
        final controller = setup.container.read(
          reportsControllerProvider.notifier,
        );
        await controller.generate(novemberFilter());

        setup.repository.fetchHandler = null;
        await controller.generate(novemberFilter());

        final state = setup.container.read(reportsControllerProvider);
        expect(state.status, ReportStatus.success);
        expect(state.errorMessage, isNull);
      },
    );

    test('ignora a resposta antiga quando o usuário gera de novo', () async {
      final setup = setUpController();
      final slow = Completer<RentalReport>();
      var call = 0;
      setup.repository.fetchHandler = (_) {
        call++;
        return call == 1
            ? slow.future
            : Future.value(RentalReport.fromRentals([sampleRentals().first]));
      };
      final controller = setup.container.read(
        reportsControllerProvider.notifier,
      );

      final first = controller.generate(novemberFilter());
      await controller.generate(novemberFilter());
      slow.complete(RentalReport.fromRentals(sampleRentals()));
      await first;

      final state = setup.container.read(reportsControllerProvider);
      expect(state.report!.totals.count, 1);
    });
  });

  group('exportPdf', () {
    test('sem relatório na tela, não faz nada', () async {
      final setup = setUpController();
      final controller = setup.container.read(
        reportsControllerProvider.notifier,
      );

      final outcome = await controller.exportPdf();

      expect(outcome, isA<ExportSkipped>());
      expect(setup.repository.exportCalls, isEmpty);
    });

    test('gera o PDF com o filtro do relatório e entrega o arquivo', () async {
      final setup = setUpController();
      final controller = setup.container.read(
        reportsControllerProvider.notifier,
      );
      await controller.generate(novemberFilter());

      final outcome = await controller.exportPdf();

      expect(outcome, isA<ExportSucceeded>());
      expect((outcome as ExportSucceeded).fileName, 'relatorio-teste.pdf');
      expect(setup.repository.exportCalls, [novemberFilter()]);
      expect(setup.saver.saved, hasLength(1));
    });

    test('liga isExporting durante a exportação e desliga no fim', () async {
      final setup = setUpController();
      final controller = setup.container.read(
        reportsControllerProvider.notifier,
      );
      await controller.generate(novemberFilter());

      final gate = Completer<void>();
      setup.repository.exportHandler = (_) async {
        await gate.future;
        return sampleReportFile();
      };

      final future = controller.exportPdf();
      expect(
        setup.container.read(reportsControllerProvider).isExporting,
        isTrue,
      );
      gate.complete();
      await future;

      expect(
        setup.container.read(reportsControllerProvider).isExporting,
        isFalse,
      );
    });

    test('um segundo pedido durante a exportação é ignorado', () async {
      final setup = setUpController();
      final controller = setup.container.read(
        reportsControllerProvider.notifier,
      );
      await controller.generate(novemberFilter());
      final gate = Completer<void>();
      setup.repository.exportHandler = (_) async {
        await gate.future;
        return sampleReportFile();
      };

      final first = controller.exportPdf();
      final second = await controller.exportPdf();
      gate.complete();
      await first;

      expect(second, isA<ExportSkipped>());
      expect(setup.repository.exportCalls, hasLength(1));
    });

    test('falha ao baixar devolve a mensagem do erro', () async {
      final setup = setUpController();
      setup.saver.error = const ReportsException('Não foi possível baixar.');
      final controller = setup.container.read(
        reportsControllerProvider.notifier,
      );
      await controller.generate(novemberFilter());

      final outcome = await controller.exportPdf();

      expect(outcome, isA<ExportFailed>());
      expect((outcome as ExportFailed).message, 'Não foi possível baixar.');
      expect(
        setup.container.read(reportsControllerProvider).isExporting,
        isFalse,
      );
    });

    test('falha inesperada devolve uma mensagem genérica', () async {
      final setup = setUpController();
      setup.repository.exportHandler = (_) =>
          Future.error(Exception('detalhe técnico'));
      final controller = setup.container.read(
        reportsControllerProvider.notifier,
      );
      await controller.generate(novemberFilter());

      final outcome = await controller.exportPdf();

      expect(outcome, isA<ExportFailed>());
      expect((outcome as ExportFailed).message, isNot(contains('técnico')));
    });
  });
}
