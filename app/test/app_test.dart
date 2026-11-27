import 'package:flutter_test/flutter_test.dart';
import 'package:tennishub/core/router/app_routes.dart';
import 'package:tennishub/features/auth/presentation/pages/login_page.dart';

import 'support/app_test_support.dart';

void main() {
  testWidgets('a área pública abre sem login', (tester) async {
    await pumpTennisHub(tester);

    expect(find.text('Agende sua quadra'), findsOneWidget);
    expect(find.text('Área do proprietário'), findsOneWidget);
  });

  testWidgets('o botão "Área do proprietário" leva ao login', (tester) async {
    await pumpTennisHub(tester);

    await tester.tap(find.text('Área do proprietário'));
    await tester.pumpAndSettle();

    expect(find.byKey(LoginKeys.submit), findsOneWidget);
  });

  testWidgets('a marca TennisHub volta para a área pública', (tester) async {
    await pumpTennisHub(tester, location: AppRoutes.login);

    await tester.tap(find.text('TennisHub'));
    await tester.pumpAndSettle();

    expect(find.text('Agende sua quadra'), findsOneWidget);
  });

  testWidgets('rota inexistente mostra a página não encontrada', (
    tester,
  ) async {
    await pumpTennisHub(tester, location: '/rota-que-nao-existe');

    expect(find.text('Página não encontrada'), findsOneWidget);

    await tester.tap(find.text('Voltar ao início'));
    await tester.pumpAndSettle();

    expect(find.text('Agende sua quadra'), findsOneWidget);
  });
}
