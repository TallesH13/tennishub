import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tennishub/core/router/app_routes.dart';
import 'package:tennishub/core/router/auth_redirect.dart';
import 'package:tennishub/core/session/owner_session.dart';
import 'package:tennishub/core/widgets/not_found_page.dart';
import 'package:tennishub/features/admin/presentation/pages/admin_home_page.dart';
import 'package:tennishub/features/admin/presentation/widgets/admin_shell.dart';
import 'package:tennishub/features/auth/presentation/pages/login_page.dart';
import 'package:tennishub/features/courts/presentation/pages/public_home_page.dart';
import 'package:tennishub/features/reports/presentation/pages/reports_page.dart';

/// Monta o roteador do app.
///
/// [isLoggedIn] diz se há sessão do proprietário; [refreshListenable] avisa
/// quando ela muda, para reaplicar as regras de acesso na tela aberta.
GoRouter createAppRouter({
  required bool Function() isLoggedIn,
  String initialLocation = AppRoutes.home,
  Listenable? refreshListenable,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: refreshListenable,
    redirect: (context, state) =>
        authRedirect(state.uri, isLoggedIn: isLoggedIn()),
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const PublicHomePage(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            AdminShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: AppRoutes.admin,
            builder: (context, state) => const AdminHomePage(),
          ),
          GoRoute(
            path: AppRoutes.adminReports,
            builder: (context, state) => const ReportsPage(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => const NotFoundPage(),
  );
}

/// Tela inicial do app. No navegador, vale o endereço digitado.
final appInitialLocationProvider = Provider<String>((ref) => AppRoutes.home);

final appRouterProvider = Provider<GoRouter>((ref) {
  final sessions = ref.read(sessionStoreProvider.notifier);
  final sessionChanges = _SessionChanges();
  ref.listen(sessionStoreProvider, (_, _) => sessionChanges.notify());

  final router = createAppRouter(
    isLoggedIn: () => sessions.isLoggedIn,
    initialLocation: ref.watch(appInitialLocationProvider),
    refreshListenable: sessionChanges,
  );
  ref.onDispose(() {
    router.dispose();
    sessionChanges.dispose();
  });
  return router;
});

/// Avisa o roteador quando o proprietário entra ou sai.
class _SessionChanges extends ChangeNotifier {
  void notify() => notifyListeners();
}
