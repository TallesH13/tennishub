import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tennishub/core/router/app_router.dart';
import 'package:tennishub/core/theme/app_theme.dart';

/// Raiz do aplicativo: junta o tema e as rotas.
class TennisHubApp extends ConsumerWidget {
  const TennisHubApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'TennisHub',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
    );
  }
}
