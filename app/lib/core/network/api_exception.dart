/// Erros que a comunicação com a API pode gerar.
///
/// Toda chamada aos repositórios lança uma destas exceções em caso de falha.
/// O [message] já vem pronto para ser mostrado ao usuário, em português.
sealed class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.code});

  /// Mensagem para o usuário.
  final String message;

  /// Status HTTP da resposta, quando houve resposta.
  final int? statusCode;

  /// Código de erro enviado pela API (ex.: `SLOT_UNAVAILABLE`).
  final String? code;

  @override
  String toString() =>
      'ApiException(${statusCode ?? '-'}, ${code ?? '-'}): $message';
}

/// Sem conexão com o servidor ou resposta demorou além do tempo limite.
final class NetworkException extends ApiException {
  const NetworkException({this.isTimeout = false})
    : super(
        isTimeout
            ? 'O servidor demorou para responder. Tente de novo em instantes.'
            : 'Não foi possível conectar ao servidor. Verifique sua internet e tente de novo.',
      );

  /// `true` quando a falha foi o tempo limite, e não a falta de conexão.
  final bool isTimeout;
}

/// Sessão do proprietário ausente ou expirada (401).
final class UnauthorizedException extends ApiException {
  const UnauthorizedException([
    super.message = 'Sua sessão expirou. Entre novamente.',
  ]) : super(statusCode: 401, code: 'UNAUTHORIZED');
}

/// E-mail ou senha incorretos no login.
final class InvalidCredentialsException extends ApiException {
  const InvalidCredentialsException([
    super.message = 'E-mail ou senha incorretos.',
  ]) : super(statusCode: 401, code: 'UNAUTHORIZED');
}

/// Muitas tentativas de login seguidas (429).
final class TooManyAttemptsException extends ApiException {
  const TooManyAttemptsException([
    super.message =
        'Muitas tentativas seguidas. Aguarde alguns minutos e tente de novo.',
  ]) : super(statusCode: 429, code: 'TOO_MANY_ATTEMPTS');
}

/// Dados recusados pela validação (422), com a mensagem de cada campo.
final class ValidationException extends ApiException {
  const ValidationException([
    super.message = 'Confira os dados informados.',
    this.fieldErrors = const {},
  ]) : super(statusCode: 422, code: 'VALIDATION_ERROR');

  /// Mensagem de erro por campo, com o nome do campo da API como chave
  /// (ex.: `customerPhone`).
  final Map<String, String> fieldErrors;
}

/// O horário escolhido já foi reservado ou não está aberto (409).
final class SlotUnavailableException extends ApiException {
  const SlotUnavailableException([
    super.message = 'Esse horário não está mais disponível. Escolha outro.',
  ]) : super(statusCode: 409, code: 'SLOT_UNAVAILABLE');
}

/// O telefone já tem 2 reservas no dia do jogo (409, RF03).
final class DailyLimitException extends ApiException {
  const DailyLimitException([
    super.message = 'Este telefone já tem 2 reservas para este dia. O limite é de 2 reservas por dia.',
  ]) : super(statusCode: 409, code: 'DAILY_LIMIT_REACHED');
}

/// O recurso pedido não existe (404).
final class NotFoundException extends ApiException {
  const NotFoundException([
    super.message = 'Não encontramos o que você procurou.',
  ]) : super(statusCode: 404, code: 'NOT_FOUND');
}

/// Conflito com o estado atual (409), como reserva já cancelada.
final class ConflictException extends ApiException {
  const ConflictException(super.message, {super.code}) : super(statusCode: 409);
}

/// Pedido recusado por outro motivo (demais respostas 4xx).
final class RequestRejectedException extends ApiException {
  const RequestRejectedException(super.message, {super.statusCode, super.code});
}

/// Falha interna do servidor (5xx).
final class ServerException extends ApiException {
  const ServerException({super.statusCode})
    : super('O servidor teve um problema. Tente de novo em instantes.');
}

/// A resposta da API veio num formato que o app não entende.
final class UnexpectedResponseException extends ApiException {
  const UnexpectedResponseException([this.detail])
    : super('Recebemos uma resposta inesperada do servidor. Tente de novo.');

  /// Detalhe técnico do problema, para depuração.
  final String? detail;
}

/// Converte uma resposta de erro da API na exceção correspondente.
///
/// A API responde erros no formato
/// `{ "error": { "code": "...", "message": "...", "details": ... } }`.
ApiException apiExceptionFromResponse(int statusCode, Object? body) {
  final error = body is Map<String, Object?> ? body['error'] : null;
  final envelope = error is Map<String, Object?>
      ? error
      : const <String, Object?>{};
  final code = envelope['code'] is String ? envelope['code']! as String : null;
  final apiMessage = envelope['message'] is String
      ? envelope['message']! as String
      : null;

  switch (code) {
    case 'SLOT_UNAVAILABLE':
      return apiMessage == null
          ? const SlotUnavailableException()
          : SlotUnavailableException(apiMessage);
    case 'DAILY_LIMIT_REACHED':
      return apiMessage == null
          ? const DailyLimitException()
          : DailyLimitException(apiMessage);
    case 'VALIDATION_ERROR':
      return ValidationException(
        apiMessage ?? 'Confira os dados informados.',
        _fieldErrors(envelope['details']),
      );
  }

  if (statusCode == 401) {
    return apiMessage == null
        ? const UnauthorizedException()
        : UnauthorizedException(apiMessage);
  }
  if (statusCode == 404) {
    return apiMessage == null
        ? const NotFoundException()
        : NotFoundException(apiMessage);
  }
  if (statusCode == 409) {
    return ConflictException(
      apiMessage ?? 'A operação não pôde ser concluída.',
      code: code,
    );
  }
  if (statusCode == 422) {
    return ValidationException(
      apiMessage ?? 'Confira os dados informados.',
      _fieldErrors(envelope['details']),
    );
  }
  if (statusCode == 429) {
    return apiMessage == null
        ? const TooManyAttemptsException()
        : TooManyAttemptsException(apiMessage);
  }
  if (statusCode >= 500) {
    return ServerException(statusCode: statusCode);
  }
  return RequestRejectedException(
    apiMessage ?? 'O pedido não pôde ser concluído.',
    statusCode: statusCode,
    code: code,
  );
}

/// Lê `details` no formato `[{ "field": "...", "message": "..." }]`.
Map<String, String> _fieldErrors(Object? details) {
  if (details is! List<Object?>) {
    return const {};
  }
  return {
    for (final item in details)
      if (item is Map<String, Object?> &&
          item['field'] is String &&
          item['message'] is String)
        item['field']! as String: item['message']! as String,
  };
}
