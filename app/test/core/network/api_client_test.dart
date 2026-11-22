import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tennishub/core/network/api_client.dart';
import 'package:tennishub/core/network/api_exception.dart';
import 'package:tennishub/core/session/owner_session.dart';

import '../../support/api_samples.dart';
import '../../support/api_test_support.dart';

void main() {
  group('requisições', () {
    test(
      'monta a URL com /api, ignora filtros vazios e envia a credencial',
      () async {
        final api = FakeApi(
          (_) async => jsonResponse({'ok': true}),
          token: sampleToken,
        );

        final data = await api.client.get(
          '/owner/bookings',
          query: {'date': '2026-12-02', 'courtId': null, 'status': ''},
        );

        expect(data, {'ok': true});
        expect(api.lastRequest.method, 'GET');
        expect(
          api.lastRequest.url.toString(),
          'http://api.test/api/owner/bookings?date=2026-12-02',
        );
        expect(api.lastRequest.headers['Authorization'], 'Bearer $sampleToken');
      },
    );

    test('sem sessão, não envia o cabeçalho Authorization', () async {
      final api = FakeApi((_) async => jsonResponse({'courts': <Object?>[]}));

      await api.client.get('/courts');

      expect(api.lastRequest.headers.containsKey('Authorization'), isFalse);
    });

    test('envia o corpo em JSON com acentos', () async {
      final api = FakeApi((_) async => jsonResponse({'ok': true}, 201));

      await api.client.post(
        '/bookings',
        body: {'customerName': 'Fábio Gonçalves'},
      );

      expect(
        api.lastRequest.headers['Content-Type'],
        startsWith('application/json'),
      );
      expect(api.lastBody, {'customerName': 'Fábio Gonçalves'});
    });

    test('resposta sem corpo (204) devolve null', () async {
      final api = FakeApi((_) async => http.Response('', 204));

      expect(await api.client.delete('/owner/blocks/3'), isNull);
      expect(api.lastRequest.method, 'DELETE');
    });

    test('baixa conteúdo binário (PDF)', () async {
      final api = FakeApi(
        (_) async => http.Response.bytes([37, 80, 68, 70], 200),
      );

      final bytes = await api.client.getBytes('/owner/reports/rentals.pdf');

      expect(bytes, [37, 80, 68, 70]);
      expect(api.lastRequest.headers['Accept'], 'application/pdf');
    });
  });

  group('erros da API', () {
    Future<void> expectError(Object body, int status, Matcher matcher) async {
      final api = FakeApi((_) async => jsonResponse(body, status));
      await expectLater(api.client.get('/qualquer'), throwsA(matcher));
    }

    test('401 lança UnauthorizedException e limpa a sessão', () async {
      final api = FakeApi((_) async => jsonResponse(sessionExpiredError, 401));

      await expectLater(
        api.client.get('/auth/me'),
        throwsA(
          isA<UnauthorizedException>().having(
            (e) => e.message,
            'message',
            'Sessão expirada por inatividade. Faça login novamente.',
          ),
        ),
      );
      expect(api.unauthorizedCalls, 1);
    });

    test('401 com notifyUnauthorized false não limpa a sessão', () async {
      final api = FakeApi(
        (_) async => jsonResponse(invalidCredentialsError, 401),
      );

      await expectLater(
        api.client.post(
          '/auth/login',
          body: const {},
          notifyUnauthorized: false,
        ),
        throwsA(isA<UnauthorizedException>()),
      );
      expect(api.unauthorizedCalls, 0);
    });

    test('409 SLOT_UNAVAILABLE vira SlotUnavailableException', () async {
      await expectError(
        slotUnavailableError,
        409,
        isA<SlotUnavailableException>(),
      );
    });

    test('409 DAILY_LIMIT_REACHED vira DailyLimitException', () async {
      await expectError(
        dailyLimitError,
        409,
        isA<DailyLimitException>().having(
          (e) => e.message,
          'message',
          'Este telefone já tem 2 reservas para 02/12/2026.',
        ),
      );
    });

    test('422 traz a mensagem de cada campo', () async {
      await expectError(
        validationError,
        422,
        isA<ValidationException>().having((e) => e.fieldErrors, 'fieldErrors', {
          'customerPhone': 'Telefone inválido.',
          'customerName': 'Informe nome e sobrenome.',
        }),
      );
    });

    test('404 vira NotFoundException', () async {
      await expectError(bookingNotFoundError, 404, isA<NotFoundException>());
    });

    test('429 vira TooManyAttemptsException', () async {
      await expectError(
        tooManyAttemptsError,
        429,
        isA<TooManyAttemptsException>(),
      );
    });

    test('500 vira ServerException sem detalhes internos', () async {
      await expectError(
        internalError,
        500,
        isA<ServerException>().having((e) => e.statusCode, 'statusCode', 500),
      );
    });

    test(
      'outro 4xx vira RequestRejectedException com a mensagem da API',
      () async {
        await expectError(
          const {
            'error': {'code': 'BAD_REQUEST', 'message': 'Corpo inválido.'},
          },
          400,
          isA<RequestRejectedException>().having(
            (e) => e.message,
            'message',
            'Corpo inválido.',
          ),
        );
      },
    );

    test('erro sem corpo JSON usa a mensagem padrão', () async {
      final api = FakeApi((_) async => http.Response('Bad Gateway', 502));

      await expectLater(
        api.client.get('/courts'),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('falhas de comunicação', () {
    test('sem conexão lança NetworkException', () async {
      final api = ApiClient(
        httpClient: offlineClient(),
        baseUrl: 'http://api.test',
      );

      await expectLater(
        api.get('/courts'),
        throwsA(
          isA<NetworkException>().having(
            (e) => e.isTimeout,
            'isTimeout',
            isFalse,
          ),
        ),
      );
    });

    test(
      'demora além do tempo limite lança NetworkException de timeout',
      () async {
        final api = FakeApi((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return jsonResponse({'ok': true});
        }, timeout: const Duration(milliseconds: 20));

        await expectLater(
          api.client.get('/courts'),
          throwsA(
            isA<NetworkException>().having(
              (e) => e.isTimeout,
              'isTimeout',
              isTrue,
            ),
          ),
        );
      },
    );

    test(
      'resposta 200 que não é JSON lança UnexpectedResponseException',
      () async {
        final api = FakeApi((_) async => http.Response('<html>', 200));

        await expectLater(
          api.client.get('/courts'),
          throwsA(isA<UnexpectedResponseException>()),
        );
      },
    );
  });

  group('credencial', () {
    test('não aparece nas mensagens de erro nem na sessão', () async {
      final api = FakeApi(
        (_) async => jsonResponse(sessionExpiredError, 401),
        token: sampleToken,
      );
      Object? error;
      try {
        await api.client.get('/auth/me');
      } on ApiException catch (e) {
        error = e;
      }

      const session = OwnerSession(
        owner: Owner(
          id: '1',
          name: 'Proprietário',
          email: 'proprietario@tennishub.com',
        ),
        token: sampleToken,
      );

      expect(error.toString(), isNot(contains(sampleToken)));
      expect(session.toString(), isNot(contains(sampleToken)));
    });

    test('a URL nunca leva a credencial', () async {
      final api = FakeApi(
        (_) async => jsonResponse({'ok': true}),
        token: sampleToken,
      );

      await api.client.get('/owner/courts');

      expect(api.lastRequest.url.toString(), isNot(contains(sampleToken)));
    });
  });

  test('MockClient recebe o corpo exatamente como enviado', () async {
    late String received;
    final api = ApiClient(
      httpClient: MockClient((request) async {
        received = request.body;
        return jsonResponse({'ok': true});
      }),
      baseUrl: '',
    );

    await api.put('/owner/courts/1', body: {'name': 'Quadra Central'});

    expect(jsonDecode(received), {'name': 'Quadra Central'});
  });
}
