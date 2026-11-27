/// Caminhos das rotas do app. Use estas constantes em vez de texto solto.
abstract final class AppRoutes {
  /// Área pública do cliente: consulta e agendamento, sem login.
  static const String home = '/';

  /// Login do proprietário.
  static const String login = '/login';

  /// Painel do proprietário. Tudo em `/admin` exige login.
  static const String admin = '/admin';

  /// Relatório de locações do proprietário (RF10).
  static const String adminReports = '/admin/relatorios';

  /// Parâmetro do login com a tela do painel para onde voltar.
  static const String returnTo = 'voltar';

  /// Se [path] é uma tela do painel.
  static bool isAdmin(String path) =>
      path == admin || path.startsWith('$admin/');
}
