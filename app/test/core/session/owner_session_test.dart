import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tennishub/core/session/owner_session.dart';
import 'package:tennishub/features/auth/data/fake_auth_repository.dart';

const OwnerSession session = OwnerSession(
  owner: FakeAuthRepository.owner,
  token: 'token',
);

void main() {
  late ProviderContainer container;
  late SessionStore store;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
    store = container.read(sessionStoreProvider.notifier);
  });

  test('expirar encerra a sessão e avisa uma única vez', () {
    store.start(session);

    store.expire();

    expect(container.read(sessionStoreProvider), isNull);
    expect(store.isLoggedIn, isFalse);
    expect(store.consumeExpired(), isTrue);
    expect(store.consumeExpired(), isFalse);
  });

  test('sair não conta como expiração', () {
    store
      ..start(session)
      ..clear();

    expect(store.consumeExpired(), isFalse);
  });

  test('401 sem sessão aberta não conta como expiração', () {
    store.expire();

    expect(store.consumeExpired(), isFalse);
  });

  test('entrar de novo esquece a expiração anterior', () {
    store
      ..start(session)
      ..expire()
      ..start(session);

    expect(store.token, 'token');
    expect(store.consumeExpired(), isFalse);
  });
}
