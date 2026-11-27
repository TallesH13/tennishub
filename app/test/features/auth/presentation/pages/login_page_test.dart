import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tennishub/core/network/api_exception.dart';
import 'package:tennishub/core/router/app_router.dart';
import 'package:tennishub/core/router/app_routes.dart';
import 'package:tennishub/core/session/owner_session.dart';
import 'package:tennishub/features/auth/data/fake_auth_repository.dart';
import 'package:tennishub/features/auth/domain/auth_repository.dart';
import 'package:tennishub/features/auth/presentation/pages/login_page.dart';
import 'package:tennishub/features/reports/data/fake_reports_repository.dart';
import 'package:tennishub/features/reports/data/reports_providers.dart';
import 'package:tennishub/features/reports/presentation/widgets/report_filter_form.dart';

import '../../../../support/app_test_support.dart';

const String welcome = 'Olá, Proprietário';

Future<void> signIn(
  WidgetTester tester, {
  String email = FakeAuthRepository.email,
  String password = FakeAuthRepository.password,
}) async {
  await tester.enterText(find.byKey(LoginKeys.email), email);
  await tester.enterText(find.byKey(LoginKeys.password), password);
  await tester.tap(find.byKey(LoginKeys.submit));
  await tester.pumpAndSettle();
}

TextField textField(WidgetTester tester, Key key) {
  return tester.widget<TextField>(
    find.descendant(of: find.byKey(key), matching: find.byType(TextField)),
  );
}

/// Login que sempre responde "muitas tentativas".
class BlockedAuthRepository implements AuthRepository {
  @override
  Future<OwnerSession> login({
    required String email,
    required String password,
  }) async {
    throw const TooManyAttemptsException(
      'Muitas tentativas de login falhas. Tente novamente em 15 minutos.',
    );
  }

  @override
  Future<Owner> fetchCurrentOwner() async =>
      throw const UnauthorizedException();

  @override
  Future<void> logout() async {}
}

void main() {
  testWidgets(
    'sem sessão, o painel leva ao login e, ao entrar, abre o painel',
    (tester) async {
      await pumpTennisHub(tester, location: AppRoutes.admin);

      expect(find.byKey(LoginKeys.submit), findsOneWidget);
      expect(find.text(welcome), findsNothing);

      await signIn(tester);

      expect(find.text(welcome), findsOneWidget);
      expect(find.text('Sair'), findsOneWidget);
    },
  );

  testWidgets(
    'credenciais inválidas: mensagem genérica, e-mail mantido e senha limpa',
    (tester) async {
      await pumpTennisHub(tester, location: AppRoutes.login);

      await signIn(tester, password: 'senha-errada');

      expect(find.text('E-mail ou senha incorretos.'), findsOneWidget);
      expect(
        textField(tester, LoginKeys.email).controller?.text,
        FakeAuthRepository.email,
      );
      expect(textField(tester, LoginKeys.password).controller?.text, isEmpty);
      expect(find.text(welcome), findsNothing);
    },
  );

  testWidgets('campos vazios pedem e-mail e senha', (tester) async {
    await pumpTennisHub(tester, location: AppRoutes.login);

    await tester.tap(find.byKey(LoginKeys.submit));
    await tester.pumpAndSettle();

    expect(find.text('Informe o e-mail.'), findsOneWidget);
    expect(find.text('Informe a senha.'), findsOneWidget);
  });

  testWidgets('quem já está logado e abre /login vai ao painel', (
    tester,
  ) async {
    await pumpTennisHub(tester, location: AppRoutes.login);
    await signIn(tester);

    appContainer(tester).read(appRouterProvider).go(AppRoutes.login);
    await tester.pumpAndSettle();

    expect(find.text(welcome), findsOneWidget);
    expect(find.byKey(LoginKeys.submit), findsNothing);
  });

  testWidgets('Sair encerra a sessão no servidor e limpa o estado local', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    await pumpTennisHub(tester, location: AppRoutes.login, auth: auth);
    await signIn(tester);

    await tester.tap(find.text('Sair'));
    await tester.pumpAndSettle();

    expect(find.byKey(LoginKeys.submit), findsOneWidget);
    expect(appContainer(tester).read(sessionStoreProvider), isNull);
    await expectLater(
      auth.fetchCurrentOwner(),
      throwsA(isA<UnauthorizedException>()),
    );
  });

  testWidgets(
    'sessão expirada (401) volta ao login e depois retorna à tela aberta',
    (tester) async {
      await pumpTennisHub(
        tester,
        location: AppRoutes.login,
        overrides: [
          reportsRepositoryProvider.overrideWithValue(FakeReportsRepository()),
        ],
      );
      await signIn(tester);
      await tester.tap(find.text('Relatórios'));
      await tester.pumpAndSettle();
      expect(find.byKey(ReportFilterKeys.from), findsOneWidget);

      // É o que o cliente HTTP faz ao receber 401 em qualquer chamada.
      appContainer(tester).read(sessionStoreProvider.notifier).expire();
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Sua sessão expirou por inatividade. Entre novamente para continuar.',
        ),
        findsOneWidget,
      );

      await signIn(tester);

      expect(find.byKey(ReportFilterKeys.from), findsOneWidget);
      expect(find.byKey(LoginKeys.submit), findsNothing);
    },
  );

  testWidgets('página recarregada com a sessão ainda válida entra direto', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    await auth.login(
      email: FakeAuthRepository.email,
      password: FakeAuthRepository.password,
    );

    await pumpTennisHub(tester, location: AppRoutes.admin, auth: auth);

    expect(find.text(welcome), findsOneWidget);
  });

  testWidgets('senha oculta, com opção de mostrar', (tester) async {
    await pumpTennisHub(tester, location: AppRoutes.login);

    expect(textField(tester, LoginKeys.password).obscureText, isTrue);

    await tester.tap(find.byKey(LoginKeys.togglePassword));
    await tester.pump();

    expect(textField(tester, LoginKeys.password).obscureText, isFalse);
  });

  testWidgets('muitas tentativas mostra o aviso e limpa a senha', (
    tester,
  ) async {
    await pumpTennisHub(
      tester,
      location: AppRoutes.login,
      auth: BlockedAuthRepository(),
    );

    await signIn(tester);

    expect(
      find.text(
        'Muitas tentativas de login falhas. Tente novamente em 15 minutos.',
      ),
      findsOneWidget,
    );
    expect(textField(tester, LoginKeys.password).controller?.text, isEmpty);
  });
}
