import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tennishub/core/fake/fake_backend.dart';
import 'package:tennishub/core/time/clock.dart';

/// Backend falso único do app, usado quando `API_MODE` é `fake`.
final fakeBackendProvider = Provider<FakeBackend>((ref) {
  return FakeBackend(
    clock: ref.watch(clockProvider),
    latency: const Duration(milliseconds: 400),
  );
});
