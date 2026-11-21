import 'package:tennishub/core/network/api_exception.dart';
import 'package:tennishub/core/session/owner_session.dart';
import 'package:tennishub/features/auth/domain/auth_repository.dart';

/// [AuthRepository] em memória, para desenvolvimento e testes.
///
/// Credenciais de teste: [email] / [password].
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.latency = Duration.zero});

  static const String email = 'proprietario@tennishub.com';

  /// Senha só do modo falso, não é a senha real da API.
  static const String password = 'tennishub123'; // secret-scan:ignore
  static const Owner owner = Owner(
    id: '1',
    name: 'Proprietário TennisHub',
    email: email,
  );

  /// Espera simulada antes de cada resposta.
  final Duration latency;

  bool _loggedIn = false;

  @override
  Future<OwnerSession> login({
    required String email,
    required String password,
  }) async {
    await _wait();
    final matches =
        email.trim().toLowerCase() == FakeAuthRepository.email &&
        password == FakeAuthRepository.password;
    if (!matches) {
      throw const InvalidCredentialsException();
    }
    _loggedIn = true;
    return const OwnerSession(
      owner: owner,
      token: 'token-falso',
      expiresIn: Duration(minutes: 30),
    );
  }

  @override
  Future<Owner> fetchCurrentOwner() async {
    await _wait();
    if (!_loggedIn) {
      throw const UnauthorizedException();
    }
    return owner;
  }

  @override
  Future<void> logout() async {
    await _wait();
    _loggedIn = false;
  }

  Future<void> _wait() async {
    if (latency > Duration.zero) {
      await Future<void>.delayed(latency);
    }
  }
}
