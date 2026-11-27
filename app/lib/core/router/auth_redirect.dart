import 'package:tennishub/core/router/app_routes.dart';

/// Decide para onde levar o usuário antes de abrir [location].
///
/// - Painel sem sessão: vai ao login, lembrando a tela pedida.
/// - Login com sessão: vai à tela lembrada ou ao início do painel.
/// - Demais casos: segue para [location] (`null`).
String? authRedirect(Uri location, {required bool isLoggedIn}) {
  if (AppRoutes.isAdmin(location.path) && !isLoggedIn) {
    return Uri(
      path: AppRoutes.login,
      queryParameters: {AppRoutes.returnTo: location.toString()},
    ).toString();
  }

  if (location.path == AppRoutes.login && isLoggedIn) {
    return _safeReturnTo(location.queryParameters[AppRoutes.returnTo]) ??
        AppRoutes.admin;
  }

  return null;
}

/// Só aceita voltar para telas do próprio painel, nunca para outro site.
String? _safeReturnTo(String? value) {
  final target = value == null ? null : Uri.tryParse(value);
  if (target == null ||
      target.hasScheme ||
      target.hasAuthority ||
      !AppRoutes.isAdmin(target.path)) {
    return null;
  }
  return target.toString();
}
