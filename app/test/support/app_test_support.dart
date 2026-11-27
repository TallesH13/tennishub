import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tennishub/app.dart';
import 'package:tennishub/core/config/app_config.dart';
import 'package:tennishub/core/router/app_router.dart';
import 'package:tennishub/core/router/app_routes.dart';
import 'package:tennishub/features/auth/data/auth_providers.dart';
import 'package:tennishub/features/auth/data/fake_auth_repository.dart';
import 'package:tennishub/features/auth/domain/auth_repository.dart';

/// Abre o app inteiro em [location], com dados falsos e sem espera simulada.
Future<void> pumpTennisHub(
  WidgetTester tester, {
  String location = AppRoutes.home,
  AuthRepository? auth,
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appInitialLocationProvider.overrideWithValue(location),
        appConfigProvider.overrideWithValue(
          AppConfig.fromUrl('http://localhost'),
        ),
        authRepositoryProvider.overrideWithValue(auth ?? FakeAuthRepository()),
        ...overrides,
      ],
      child: const TennisHubApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Providers do app aberto por [pumpTennisHub].
ProviderContainer appContainer(WidgetTester tester) {
  return ProviderScope.containerOf(tester.element(find.byType(TennisHubApp)));
}
