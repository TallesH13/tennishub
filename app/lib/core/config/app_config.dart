import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Configurações recebidas na compilação, via `--dart-define`.
///
/// Exemplo:
/// `flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080`
class AppConfig {
  const AppConfig._(this.apiBaseUrl);

  /// Cria a configuração a partir de um endereço, sem a barra final.
  factory AppConfig.fromUrl(String url) {
    final trimmed = url.trim();
    final withoutTrailingSlash = trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
    return AppConfig._(withoutTrailingSlash);
  }

  /// Lê o `API_BASE_URL` definido na compilação.
  ///
  /// Sem ele, usa o mesmo endereço em que o app foi aberto, porque na
  /// apresentação a própria API serve o build do Flutter (issue #33).
  factory AppConfig.fromEnvironment() {
    const definedUrl = String.fromEnvironment('API_BASE_URL');
    return AppConfig.fromUrl(
      definedUrl.isEmpty ? _currentOrigin() : definedUrl,
    );
  }

  /// Endereço base da API, sem barra no final.
  final String apiBaseUrl;

  static String _currentOrigin() {
    final base = Uri.base;
    final isWeb = base.scheme == 'http' || base.scheme == 'https';
    return isWeb ? base.origin : '';
  }
}

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);
