import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tennishub/core/network/api_client.dart';

/// Resposta JSON em UTF-8, como a API devolve.
http.Response jsonResponse(Object? body, [int statusCode = 200]) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

/// Cliente da API que responde com [handler] e guarda as requisições feitas.
class FakeApi {
  FakeApi(
    MockClientHandler handler, {
    String? token,
    Duration timeout = const Duration(seconds: 5),
  }) {
    client = ApiClient(
      httpClient: MockClient((request) {
        requests.add(request);
        return handler(request);
      }),
      baseUrl: 'http://api.test',
      readToken: () => token,
      onUnauthorized: () => unauthorizedCalls++,
      timeout: timeout,
    );
  }

  late final ApiClient client;
  final List<http.Request> requests = [];
  int unauthorizedCalls = 0;

  http.Request get lastRequest => requests.last;

  /// Corpo JSON da última requisição.
  Object? get lastBody => jsonDecode(lastRequest.body);
}

/// Cliente HTTP que simula falta de conexão.
MockClient offlineClient() =>
    MockClient((_) async => throw http.ClientException('sem conexão'));
