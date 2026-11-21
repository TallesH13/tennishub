import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tennishub/core/router/app_routes.dart';
import 'package:tennishub/core/widgets/not_found_page.dart';
import 'package:tennishub/features/admin/presentation/pages/admin_home_page.dart';
import 'package:tennishub/features/courts/presentation/pages/public_home_page.dart';
import 'package:tennishub/features/reports/presentation/pages/reports_page.dart';

/// Monta o roteador do app. O [initialLocation] existe para os testes.
GoRouter createAppRouter({String initialLocation = AppRoutes.home}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const PublicHomePage(),
      ),
      GoRoute(
        path: AppRoutes.admin,
        builder: (context, state) => const AdminHomePage(),
      ),
      GoRoute(
        path: AppRoutes.adminReports,
        builder: (context, state) => const ReportsPage(),
      ),
    ],
    errorBuilder: (context, state) => const NotFoundPage(),
  );
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = createAppRouter();
  ref.onDispose(router.dispose);
  return router;
});
