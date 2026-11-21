import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tennishub/core/network/api_exception.dart';
import 'package:tennishub/core/session/owner_session.dart';
import 'package:tennishub/features/auth/data/auth_providers.dart';
import 'package:tennishub/features/auth/domain/auth_repository.dart';

/// Entra, sai e recupera a sessão do proprietário, guardando o resultado no
/// [SessionStore]. A tela de login (issue #25) usa esta classe.
class AuthController {
  AuthController(this._repository, this._sessions);

  final AuthRepository _repository;
  final SessionStore _sessions;

  /// Lança `InvalidCredentialsException`, `TooManyAttemptsException` ou
  /// `NetworkException`; a sessão só é guardada em caso de sucesso.
  Future<void> signIn({required String email, required String password}) async {
    final session = await _repository.login(email: email, password: password);
    _sessions.start(session);
  }

  /// Encerra a sessão na API e no app. Mesmo se a API falhar, o app sai.
  Future<void> signOut() async {
    try {
      await _repository.logout();
    } on ApiException {
      // A sessão local é limpa de qualquer forma.
    } finally {
      _sessions.clear();
    }
  }

  /// Tenta recuperar a sessão ao abrir o app (cookie da API ainda válido).
  ///
  /// Devolve `true` se o proprietário continua logado.
  Future<bool> restoreSession() async {
    try {
      final owner = await _repository.fetchCurrentOwner();
      _sessions.start(OwnerSession(owner: owner));
      return true;
    } on UnauthorizedException {
      _sessions.clear();
      return false;
    }
  }
}

final authControllerProvider = Provider<AuthController>((ref) {
  return AuthController(
    ref.watch(authRepositoryProvider),
    ref.read(sessionStoreProvider.notifier),
  );
});
