import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:tennishub/core/config/app_config.dart';
import 'package:tennishub/core/network/api_client.dart';
import 'package:tennishub/core/session/owner_session.dart';

/// Cliente HTTP de baixo nível. Nos testes, troque por um `MockClient`.
final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// Cliente da API, já ligado à sessão do proprietário.
final apiClientProvider = Provider<ApiClient>((ref) {
  final sessions = ref.read(sessionStoreProvider.notifier);
  return ApiClient(
    httpClient: ref.watch(httpClientProvider),
    baseUrl: ref.watch(appConfigProvider).apiBaseUrl,
    readToken: () => sessions.token,
    onUnauthorized: sessions.expire,
  );
});
