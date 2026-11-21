import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tennishub/core/network/json_reader.dart';

/// Proprietário do clube (há um só no sistema, D09).
final class Owner {
  const Owner({required this.id, required this.name, required this.email});

  factory Owner.fromJson(JsonMap json) {
    return Owner(
      id: json.readId('id'),
      name: json.readString('name'),
      email: json.readString('email'),
    );
  }

  final String id;
  final String name;
  final String email;
}

/// Sessão do proprietário logado.
final class OwnerSession {
  const OwnerSession({required this.owner, this.token, this.expiresIn});

  final Owner owner;

  /// Credencial enviada no cabeçalho `Authorization`.
  ///
  /// Pode ser `null` quando a sessão foi recuperada pelo cookie da API
  /// (página recarregada): o navegador envia o cookie sozinho.
  final String? token;

  /// Tempo de inatividade até a sessão expirar, informado pela API.
  final Duration? expiresIn;

  /// Nunca expõe a credencial, nem em log.
  @override
  String toString() => 'OwnerSession(owner: ${owner.email}, token: ***)';
}

/// Guarda a sessão atual do proprietário (`null` = deslogado).
///
/// O cliente HTTP lê a credencial daqui e limpa a sessão ao receber 401.
/// As rotas do painel (issue #25) observam este estado para mandar ao login.
class SessionStore extends Notifier<OwnerSession?> {
  @override
  OwnerSession? build() => null;

  /// Credencial atual, ou `null` sem sessão.
  String? get token => state?.token;

  void start(OwnerSession session) => state = session;

  void clear() => state = null;
}

final sessionStoreProvider = NotifierProvider<SessionStore, OwnerSession?>(
  SessionStore.new,
);
