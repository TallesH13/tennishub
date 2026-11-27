import 'package:tennishub/core/network/api_client.dart';
import 'package:tennishub/core/network/api_exception.dart';
import 'package:tennishub/core/network/json_reader.dart';
import 'package:tennishub/core/session/owner_session.dart';
import 'package:tennishub/features/auth/domain/auth_repository.dart';

/// [AuthRepository] ligado à API (`/api/auth/*`).
class HttpAuthRepository implements AuthRepository {
  HttpAuthRepository(this._api);

  final ApiClient _api;

  @override
  Future<OwnerSession> login({
    required String email,
    required String password,
  }) async {
    final Object? data;
    try {
      data = await _api.post(
        '/auth/login',
        body: {'email': email.trim(), 'password': password},
        // 401 aqui é senha errada, não sessão expirada.
        notifyUnauthorized: false,
      );
    } on UnauthorizedException catch (error) {
      throw InvalidCredentialsException(error.message);
    }

    return parseResponse(() {
      final json = asJsonMap(data);
      return OwnerSession(
        owner: Owner.fromJson(json.readMap('owner')),
        token: json.readString('token'),
        expiresIn: Duration(seconds: json.readInt('expiresIn')),
      );
    });
  }

  @override
  Future<Owner> fetchCurrentOwner() async {
    // Sem sessão, o 401 aqui é a resposta esperada, não uma expiração.
    final data = await _api.get('/auth/me', notifyUnauthorized: false);
    return parseResponse(
      () => Owner.fromJson(asJsonMap(data).readMap('owner')),
    );
  }

  @override
  Future<void> logout() async {
    await _api.post('/auth/logout');
  }
}
