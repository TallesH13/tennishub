import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tennishub/core/config/app_config.dart';
import 'package:tennishub/core/fake/fake_backend_provider.dart';
import 'package:tennishub/core/time/clock.dart';
import 'package:tennishub/features/auth/data/auth_providers.dart';
import 'package:tennishub/features/auth/data/fake_auth_repository.dart';
import 'package:tennishub/features/auth/data/http_auth_repository.dart';
import 'package:tennishub/features/bookings/data/bookings_providers.dart';
import 'package:tennishub/features/bookings/data/fake_bookings_repository.dart';
import 'package:tennishub/features/bookings/data/http_bookings_repository.dart';
import 'package:tennishub/features/courts/data/courts_providers.dart';
import 'package:tennishub/features/courts/data/fake_courts_repository.dart';
import 'package:tennishub/features/courts/data/http_courts_repository.dart';
import 'package:tennishub/features/reports/data/fake_reports_repository.dart';
import 'package:tennishub/features/reports/data/http_reports_repository.dart';
import 'package:tennishub/features/reports/data/reports_providers.dart';

ProviderContainer containerFor(ApiMode mode) {
  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(
        AppConfig.fromUrl('http://api.test', apiMode: mode),
      ),
      clockProvider.overrideWithValue(() => DateTime(2026, 12, 1, 9)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('API_MODE=fake usa as implementações em memória', () {
    final container = containerFor(ApiMode.fake);

    expect(container.read(authRepositoryProvider), isA<FakeAuthRepository>());
    expect(
      container.read(courtsRepositoryProvider),
      isA<FakeCourtsRepository>(),
    );
    expect(
      container.read(courtScheduleRepositoryProvider),
      isA<FakeCourtScheduleRepository>(),
    );
    expect(
      container.read(bookingsRepositoryProvider),
      isA<FakeBookingsRepository>(),
    );
    expect(
      container.read(ownerBookingsRepositoryProvider),
      isA<FakeOwnerBookingsRepository>(),
    );
    expect(
      container.read(reportsRepositoryProvider),
      isA<FakeReportsRepository>(),
    );
  });

  test('API_MODE=http usa a API', () {
    final container = containerFor(ApiMode.http);

    expect(container.read(authRepositoryProvider), isA<HttpAuthRepository>());
    expect(
      container.read(courtsRepositoryProvider),
      isA<HttpCourtsRepository>(),
    );
    expect(
      container.read(courtScheduleRepositoryProvider),
      isA<HttpCourtScheduleRepository>(),
    );
    expect(
      container.read(bookingsRepositoryProvider),
      isA<HttpBookingsRepository>(),
    );
    expect(
      container.read(ownerBookingsRepositoryProvider),
      isA<HttpOwnerBookingsRepository>(),
    );
    expect(
      container.read(reportsRepositoryProvider),
      isA<HttpReportsRepository>(),
    );
  });

  test('quadras e reservas falsas compartilham o mesmo backend', () {
    final container = containerFor(ApiMode.fake);
    final backend = container.read(fakeBackendProvider);

    expect(backend.latency, const Duration(milliseconds: 400));
    expect(identical(backend, container.read(fakeBackendProvider)), isTrue);
  });

  test('API_MODE aceita só "http" como API real', () {
    expect(ApiMode.parse(' HTTP '), ApiMode.http);
    expect(ApiMode.parse('fake'), ApiMode.fake);
    expect(ApiMode.parse('qualquer'), ApiMode.fake);
  });
}
