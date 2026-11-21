import 'package:flutter_riverpod/flutter_riverpod.dart';

/// De onde vêm os dados do app.
enum ApiMode {
  /// Implementações falsas em memória: o app roda sem a API.
  fake,

  /// API real, no endereço de [AppConfig.apiBaseUrl].
  http;

  /// Lê o valor de `API_MODE` (`fake` ou `http`); qualquer outro vira [fake].
  static ApiMode parse(String value) =>
      value.trim().toLowerCase() == 'http' ? ApiMode.http : ApiMode.fake;
}

/// Configurações recebidas na compilação, via `--dart-define`.
///
/// Exemplos:
/// `flutter run -d chrome` (dados falsos, sem API)
/// `flutter run -d chrome --dart-define=API_MODE=http --dart-define=API_BASE_URL=http://localhost:8080`
class AppConfig {
  const AppConfig._(this.apiBaseUrl, this.apiMode);

  /// Cria a configuração a partir de um endereço, sem a barra final.
  factory AppConfig.fromUrl(String url, {ApiMode apiMode = ApiMode.fake}) {
    final trimmed = url.trim();
    final withoutTrailingSlash = trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
    return AppConfig._(withoutTrailingSlash, apiMode);
  }

  /// Lê o `API_BASE_URL` e o `API_MODE` definidos na compilação.
  ///
  /// Sem ele, usa o mesmo endereço em que o app foi aberto, porque na
  /// apresentação a própria API serve o build do Flutter (issue #33).
  factory AppConfig.fromEnvironment() {
    const definedUrl = String.fromEnvironment('API_BASE_URL');
    const definedMode = String.fromEnvironment(
      'API_MODE',
      defaultValue: 'fake',
    );
    return AppConfig.fromUrl(
      definedUrl.isEmpty ? _currentOrigin() : definedUrl,
      apiMode: ApiMode.parse(definedMode),
    );
  }

  /// Endereço base da API, sem barra no final.
  final String apiBaseUrl;

  /// Se o app usa a API real ou as implementações falsas.
  final ApiMode apiMode;

  static String _currentOrigin() {
    final base = Uri.base;
    final isWeb = base.scheme == 'http' || base.scheme == 'https';
    return isWeb ? base.origin : '';
  }
}

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);
