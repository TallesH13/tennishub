import 'package:flutter_test/flutter_test.dart';
import 'package:tennishub/core/network/api_client.dart';
import 'package:tennishub/core/network/api_exception.dart';
import 'package:tennishub/features/auth/data/http_auth_repository.dart';

import '../../../support/api_samples.dart';
import '../../../support/api_test_support.dart';

void main() {
  test('login envia e-mail e senha e lê a resposta real da API', () async {
    final api = FakeApi((_) async => jsonResponse(loginResponse));

    final session = await HttpAuthRepository(api.client)
        .login(email: '  proprietario@tennishub.com ', password: 'Senha123');

    expect(api.lastRequest.url.path, '/api/auth/login');
    expect(api.lastBody, {
      'email': 'proprietario@tennishub.com',
      'password': 'Senha123',
    });
    expect(session.token, sampleToken);
    expect(session.expiresIn, const Duration(minutes: 30));
    expect(session.owner.id, '1');
    expect(session.owner.name, 'Proprietário TennisHub');
  });

  test(
    'senha errada vira InvalidCredentialsException sem limpar a sessão',
    () async {
      final api = FakeApi(
        (_) async => jsonResponse(invalidCredentialsError, 401),
      );

      await expectLater(
        HttpAuthRepository(api.client)
            .login(email: 'x@y.com', password: 'errada'),
        throwsA(
          isA<InvalidCredentialsException>().having(
            (e) => e.message,
            'message',
            'E-mail ou senha inválidos.',
          ),
        ),
      );
      expect(api.unauthorizedCalls, 0);
    },
  );

  test('muitas tentativas vira TooManyAttemptsException', () async {
    final api = FakeApi((_) async => jsonResponse(tooManyAttemptsError, 429));

    await expectLater(
      HttpAuthRepository(api.client)
          .login(email: 'x@y.com', password: 'errada'),
      throwsA(isA<TooManyAttemptsException>()),
    );
  });

  test('busca o proprietário da sessão atual', () async {
    final api = FakeApi(
      (_) async => jsonResponse(meResponse),
      token: sampleToken,
    );

    final owner = await HttpAuthRepository(api.client).fetchCurrentOwner();

    expect(api.lastRequest.url.path, '/api/auth/me');
    expect(owner.email, 'proprietario@tennishub.com');
  });

  test('sessão expirada limpa a sessão local', () async {
    final api = FakeApi(
      (_) async => jsonResponse(sessionExpiredError, 401),
      token: sampleToken,
    );

    await expectLater(
      HttpAuthRepository(api.client).fetchCurrentOwner(),
      throwsA(isA<UnauthorizedException>()),
    );
    expect(api.unauthorizedCalls, 1);
  });

  test('falha de rede no login lança NetworkException', () async {
    final repository = HttpAuthRepository(
      ApiClient(httpClient: offlineClient(), baseUrl: 'http://api.test'),
    );

    await expectLater(
      repository.login(email: 'x@y.com', password: 'Senha123'),
      throwsA(isA<NetworkException>()),
    );
  });

  test(
    'resposta de login incompleta lança UnexpectedResponseException',
    () async {
      final api = FakeApi((_) async => jsonResponse({'token': sampleToken}));

      await expectLater(
        HttpAuthRepository(api.client)
            .login(email: 'x@y.com', password: 'Senha123'),
        throwsA(isA<UnexpectedResponseException>()),
      );
    },
  );
}
