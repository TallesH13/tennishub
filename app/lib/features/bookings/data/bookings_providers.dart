import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tennishub/core/config/app_config.dart';
import 'package:tennishub/core/fake/fake_backend_provider.dart';
import 'package:tennishub/core/network/network_providers.dart';
import 'package:tennishub/features/bookings/data/fake_bookings_repository.dart';
import 'package:tennishub/features/bookings/data/http_bookings_repository.dart';
import 'package:tennishub/features/bookings/domain/bookings_repository.dart';

/// Reservas do cliente: API real ou implementação falsa (`API_MODE`).
final bookingsRepositoryProvider = Provider<BookingsRepository>((ref) {
  return switch (ref.watch(appConfigProvider).apiMode) {
    ApiMode.http => HttpBookingsRepository(ref.watch(apiClientProvider)),
    ApiMode.fake => FakeBookingsRepository(ref.watch(fakeBackendProvider)),
  };
});

/// Agendamentos do painel: API real ou implementação falsa (`API_MODE`).
final ownerBookingsRepositoryProvider = Provider<OwnerBookingsRepository>((
  ref,
) {
  return switch (ref.watch(appConfigProvider).apiMode) {
    ApiMode.http => HttpOwnerBookingsRepository(ref.watch(apiClientProvider)),
    ApiMode.fake => FakeOwnerBookingsRepository(ref.watch(fakeBackendProvider)),
  };
});
