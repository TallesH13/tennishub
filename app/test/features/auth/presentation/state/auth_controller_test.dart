import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tennishub/core/config/app_config.dart';
import 'package:tennishub/core/network/api_exception.dart';
import 'package:tennishub/core/network/network_providers.dart';
import 'package:tennishub/core/session/owner_session.dart';
import 'package:tennishub/features/auth/data/auth_providers.dart';
import 'package:tennishub/features/auth/data/fake_auth_repository.dart';
import 'package:tennishub/features/auth/presentation/state/auth_controller.dart';
import 'package:tennishub/features/courts/data/courts_providers.dart';

import '../../../../support/api_samples.dart';
import '../../../../support/api_test_support.dart';

ProviderContainer containerWith({
  ApiMode mode = ApiMode.http,
  http.Client? client,
}) {
  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(
        AppConfig.fromUrl('http://api.test', apiMode: mode),
      ),
      if (client != null) httpClientProvider.overrideWithValue(client),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('com a API', () {
    test('guarda a credencial, envia nas chamadas seguintes e limpa a sessão no 401', () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        switch (request.url.path) {
          case '/api/auth/login':
            return jsonResponse(loginResponse);
          case '/api/auth/me':
            return jsonResponse(meResponse);
          case '/api/owner/courts':
            return jsonResponse(sessionExpiredError, 401);
        }
        return jsonResponse(bookingNotFoundError, 404);
      });
      final container = containerWith(client: client);

      await container
          .read(authControllerProvider)
          .signIn(email: 'proprietario@tennishub.com', password: 'Senha123');
      expect(
        container.read(sessionStoreProvider)?.owner.name,
        'Proprietário TennisHub',
      );

      final repository = container.read(authRepositoryProvider);
      await repository.fetchCurrentOwner();
      expect(requests.last.headers['Authorization'], 'Bearer $sampleToken');

      // Qualquer chamada do painel com 401 encerra a sessão como expirada.
      await expectLater(
        container.read(courtsRepositoryProvider).listAllCourts(),
        throwsA(isA<UnauthorizedException>()),
      );
      expect(container.read(sessionStoreProvider), isNull);
      expect(
        container.read(sessionStoreProvider.notifier).consumeExpired(),
        isTrue,
      );
    });

    test('login recusado não guarda sessão', () async {
      final container = containerWith(
        client: MockClient(
          (_) async => jsonResponse(invalidCredentialsError, 401),
        ),
      );

      await expectLater(
        container
            .read(authControllerProvider)
            .signIn(email: 'x@y.com', password: 'errada'),
        throwsA(isA<InvalidCredentialsException>()),
      );
      expect(container.read(sessionStoreProvider), isNull);
    });

    test('sair limpa a sessão mesmo sem conexão', () async {
      final container = containerWith(client: offlineClient());
      container
          .read(sessionStoreProvider.notifier)
          .start(
            const OwnerSession(
              owner: FakeAuthRepository.owner,
              token: sampleToken,
            ),
          );

      await container.read(authControllerProvider).signOut();

      expect(container.read(sessionStoreProvider), isNull);
    });
  });

  group('com a implementação falsa', () {
    test('entra com as credenciais de teste e recupera a sessão', () async {
      final container = containerWith(mode: ApiMode.fake);
      final auth = container.read(authControllerProvider);

      await auth.signIn(
        email: FakeAuthRepository.email,
        password: FakeAuthRepository.password,
      );

      expect(
        container.read(sessionStoreProvider)?.owner.email,
        FakeAuthRepository.email,
      );
      expect(await auth.restoreSession(), isTrue);
    });

    test('sem login, restaurar a sessão devolve false', () async {
      final container = containerWith(mode: ApiMode.fake);

      expect(
        await container.read(authControllerProvider).restoreSession(),
        isFalse,
      );
      expect(container.read(sessionStoreProvider), isNull);
    });
  });
}
