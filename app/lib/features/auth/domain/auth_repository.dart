import 'package:tennishub/core/session/owner_session.dart';

/// Login do proprietário (RF05).
///
/// Os métodos lançam `ApiException` (core/network) em caso de falha.
abstract interface class AuthRepository {
  /// Lança `InvalidCredentialsException` para e-mail ou senha errados e
  /// `TooManyAttemptsException` após muitas tentativas seguidas.
  Future<OwnerSession> login({required String email, required String password});

  /// Proprietário da sessão atual. Lança `UnauthorizedException` sem sessão.
  Future<Owner> fetchCurrentOwner();

  Future<void> logout();
}
