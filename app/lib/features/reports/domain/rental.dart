/// Uma locação realizada: uma reserva de quadra cujo horário já passou.
final class Rental {
  const Rental({
    required this.id,
    required this.startsAt,
    required this.courtId,
    required this.courtName,
    required this.clientName,
    required this.clientPhone,
    this.valueCents,
  });

  final String id;

  /// Início da locação.
  final DateTime startsAt;

  final String courtId;
  final String courtName;

  /// Nome completo informado pelo cliente no agendamento.
  final String clientName;

  /// Telefone do cliente, só com os dígitos.
  final String clientPhone;

  /// Valor da locação em centavos. `null` quando a quadra não tem valor por
  /// hora cadastrado.
  final int? valueCents;

  /// Horas locadas. Todo agendamento tem exatamente 1 hora (regra do projeto).
  int get hours => 1;
}
