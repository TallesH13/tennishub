/// Problemas possíveis no período escolhido para o relatório.
enum ReportPeriodError {
  /// A data final é anterior à inicial.
  endBeforeStart,

  /// O período passa de 1 ano.
  tooLong,
}

/// Filtros do relatório de locações: período (obrigatório) e, opcionalmente,
/// cliente e quadra.
///
/// As datas guardam só o dia (sem hora) e o período inclui o dia final.
final class ReportFilter {
  const ReportFilter({
    required this.from,
    required this.to,
    this.client,
    this.courtId,
  });

  /// Do primeiro ao último dia do mês de [today].
  factory ReportFilter.thisMonth(DateTime today) {
    return ReportFilter(
      from: DateTime(today.year, today.month),
      to: DateTime(today.year, today.month + 1, 0),
    );
  }

  /// Do primeiro ao último dia do mês anterior ao de [today].
  factory ReportFilter.lastMonth(DateTime today) {
    return ReportFilter(
      from: DateTime(today.year, today.month - 1),
      to: DateTime(today.year, today.month, 0),
    );
  }

  /// Primeiro dia do período.
  final DateTime from;

  /// Último dia do período, incluído no relatório.
  final DateTime to;

  /// Nome (parcial) ou telefone do cliente. `null` traz todos os clientes.
  final String? client;

  /// Quadra escolhida. `null` traz todas as quadras.
  final String? courtId;

  /// Problema no período, ou `null` quando ele é válido.
  ReportPeriodError? get periodError {
    if (to.isBefore(from)) {
      return ReportPeriodError.endBeforeStart;
    }

    final limit = DateTime(from.year + 1, from.month, from.day);
    if (to.isAfter(limit)) {
      return ReportPeriodError.tooLong;
    }

    return null;
  }

  /// Cópia com os campos trocados. Use [clearClient] e [clearCourt] para
  /// voltar a "todos", já que `null` sozinho significa "não mudar".
  ReportFilter copyWith({
    DateTime? from,
    DateTime? to,
    String? client,
    bool clearClient = false,
    String? courtId,
    bool clearCourt = false,
  }) {
    return ReportFilter(
      from: from ?? this.from,
      to: to ?? this.to,
      client: clearClient ? null : client ?? this.client,
      courtId: clearCourt ? null : courtId ?? this.courtId,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ReportFilter &&
        other.from == from &&
        other.to == to &&
        other.client == client &&
        other.courtId == courtId;
  }

  @override
  int get hashCode => Object.hash(from, to, client, courtId);
}
