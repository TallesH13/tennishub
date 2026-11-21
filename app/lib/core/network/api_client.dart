import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:tennishub/core/network/api_exception.dart';

/// Devolve a credencial atual do proprietário, ou `null` sem sessão.
typedef TokenReader = String? Function();

/// Cliente HTTP do app: monta as URLs da API, envia a credencial do
/// proprietário, aplica o tempo limite e traduz os erros em [ApiException].
///
/// Todas as rotas ficam em `<apiBaseUrl>/api`. A credencial nunca é escrita
/// em log nem aparece nas mensagens de erro.
class ApiClient {
  ApiClient({
    required http.Client httpClient,
    required this.baseUrl,
    TokenReader? readToken,
    void Function()? onUnauthorized,
    this.timeout = const Duration(seconds: 15),
  }) : _http = httpClient,
       _readToken = readToken ?? _noToken,
       _onUnauthorized = onUnauthorized ?? _doNothing;

  /// Prefixo de todas as rotas REST da API.
  static const String apiPrefix = '/api';

  final http.Client _http;
  final String baseUrl;
  final TokenReader _readToken;
  final void Function() _onUnauthorized;

  /// Tempo máximo de espera por uma resposta.
  final Duration timeout;

  static String? _noToken() => null;
  static void _doNothing() {}

  /// `GET` que devolve o JSON da resposta.
  Future<Object?> get(String path, {Map<String, String?> query = const {}}) {
    return _json('GET', path, query: query);
  }

  /// `POST` com corpo JSON.
  ///
  /// Use [notifyUnauthorized] `false` quando um 401 não significar sessão
  /// expirada (ex.: senha errada no login).
  Future<Object?> post(
    String path, {
    Object? body,
    bool notifyUnauthorized = true,
  }) {
    return _json(
      'POST',
      path,
      body: body,
      notifyUnauthorized: notifyUnauthorized,
    );
  }

  /// `PUT` com corpo JSON.
  Future<Object?> put(String path, {Object? body}) {
    return _json('PUT', path, body: body);
  }

  /// `DELETE`.
  Future<Object?> delete(String path) => _json('DELETE', path);

  /// `GET` que devolve o conteúdo bruto (ex.: PDF).
  Future<Uint8List> getBytes(
    String path, {
    Map<String, String?> query = const {},
  }) async {
    final response = await _send(
      'GET',
      path,
      query: query,
      accept: 'application/pdf',
    );
    return response.bodyBytes;
  }

  /// Monta a URL completa de uma rota, ignorando parâmetros vazios.
  Uri buildUri(String path, [Map<String, String?> query = const {}]) {
    final parameters = <String, String>{
      for (final MapEntry(:key, :value) in query.entries)
        if (value != null && value.isNotEmpty) key: value,
    };
    final uri = Uri.parse('$baseUrl$apiPrefix$path');
    return parameters.isEmpty ? uri : uri.replace(queryParameters: parameters);
  }

  Future<Object?> _json(
    String method,
    String path, {
    Map<String, String?> query = const {},
    Object? body,
    bool notifyUnauthorized = true,
  }) async {
    final response = await _send(
      method,
      path,
      query: query,
      body: body,
      notifyUnauthorized: notifyUnauthorized,
    );
    if (response.bodyBytes.isEmpty) {
      return null;
    }
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const UnexpectedResponseException('Corpo da resposta não é JSON.');
    }
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, String?> query = const {},
    Object? body,
    bool notifyUnauthorized = true,
    String accept = 'application/json',
  }) async {
    final request = http.Request(method, buildUri(path, query));
    request.headers['Accept'] = accept;

    final token = _readToken();
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    if (body != null) {
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      request.body = jsonEncode(body);
    }

    final http.Response response;
    try {
      final streamed = await _http.send(request).timeout(timeout);
      response = await http.Response.fromStream(streamed).timeout(timeout);
    } on TimeoutException {
      throw const NetworkException(isTimeout: true);
    } on http.ClientException {
      throw const NetworkException();
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    }

    final error = apiExceptionFromResponse(
      response.statusCode,
      _tryDecode(response),
    );
    if (error is UnauthorizedException && notifyUnauthorized) {
      _onUnauthorized();
    }
    throw error;
  }

  static Object? _tryDecode(http.Response response) {
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      return null;
    }
  }
}
