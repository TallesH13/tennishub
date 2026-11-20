/// Caminhos das rotas do app. Use estas constantes em vez de texto solto.
abstract final class AppRoutes {
  /// Área pública do cliente: consulta e agendamento, sem login.
  static const String home = '/';

  /// Painel do proprietário. Passa a exigir login na issue #25.
  static const String admin = '/admin';
}
