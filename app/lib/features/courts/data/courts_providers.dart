import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tennishub/core/config/app_config.dart';
import 'package:tennishub/core/fake/fake_backend_provider.dart';
import 'package:tennishub/core/network/network_providers.dart';
import 'package:tennishub/core/time/clock.dart';
import 'package:tennishub/features/courts/data/fake_courts_repository.dart';
import 'package:tennishub/features/courts/data/http_courts_repository.dart';
import 'package:tennishub/features/courts/domain/courts_repository.dart';

/// Quadras e horários livres: API real ou implementação falsa (`API_MODE`).
final courtsRepositoryProvider = Provider<CourtsRepository>((ref) {
  return switch (ref.watch(appConfigProvider).apiMode) {
    ApiMode.http => HttpCourtsRepository(ref.watch(apiClientProvider)),
    ApiMode.fake => FakeCourtsRepository(ref.watch(fakeBackendProvider)),
  };
});

/// Horário de funcionamento e bloqueios: API real ou implementação falsa.
final courtScheduleRepositoryProvider = Provider<CourtScheduleRepository>((
  ref,
) {
  return switch (ref.watch(appConfigProvider).apiMode) {
    ApiMode.http => HttpCourtScheduleRepository(ref.watch(apiClientProvider)),
    ApiMode.fake => FakeCourtScheduleRepository(
      ref.watch(fakeBackendProvider),
      today: ref.watch(clockProvider),
    ),
  };
});
