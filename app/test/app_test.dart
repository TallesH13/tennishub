import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tennishub/app.dart';
import 'package:tennishub/core/router/app_router.dart';
import 'package:tennishub/core/router/app_routes.dart';

/// Abre o app inteiro já na rota [initialLocation].
Future<void> pumpApp(
  WidgetTester tester, {
  String initialLocation = AppRoutes.home,
}) async {
  final router = createAppRouter(initialLocation: initialLocation);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [appRouterProvider.overrideWithValue(router)],
      child: const TennisHubApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a área pública abre sem login', (tester) async {
    await pumpApp(tester);

    expect(find.text('Agende sua quadra'), findsOneWidget);
    expect(find.text('Área do proprietário'), findsOneWidget);
  });

  testWidgets('o botão "Área do proprietário" abre o painel', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Área do proprietário'));
    await tester.pumpAndSettle();

    expect(find.text('Painel do proprietário'), findsOneWidget);
  });

  testWidgets('a marca TennisHub volta para a área pública', (tester) async {
    await pumpApp(tester, initialLocation: AppRoutes.admin);

    await tester.tap(find.text('TennisHub'));
    await tester.pumpAndSettle();

    expect(find.text('Agende sua quadra'), findsOneWidget);
  });

  testWidgets('rota inexistente mostra a página não encontrada', (
    tester,
  ) async {
    await pumpApp(tester, initialLocation: '/rota-que-nao-existe');

    expect(find.text('Página não encontrada'), findsOneWidget);

    await tester.tap(find.text('Voltar ao início'));
    await tester.pumpAndSettle();

    expect(find.text('Agende sua quadra'), findsOneWidget);
  });
}
