import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tennishub/core/config/app_config.dart';
import 'package:tennishub/core/network/network_providers.dart';
import 'package:tennishub/features/auth/data/fake_auth_repository.dart';
import 'package:tennishub/features/auth/data/http_auth_repository.dart';
import 'package:tennishub/features/auth/domain/auth_repository.dart';

/// Login do proprietário: API real ou implementação falsa (`API_MODE`).
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return switch (ref.watch(appConfigProvider).apiMode) {
    ApiMode.http => HttpAuthRepository(ref.watch(apiClientProvider)),
    ApiMode.fake => FakeAuthRepository(
      latency: const Duration(milliseconds: 400),
    ),
  };
});
