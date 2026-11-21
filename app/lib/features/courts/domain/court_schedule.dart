import 'package:tennishub/core/network/json_reader.dart';

/// Dia da semana no formato da API: 0 = domingo ... 6 = sábado.
int apiWeekdayOf(DateTime date) => date.weekday % 7;

/// Faixa de funcionamento num dia da semana. `startHour = 8` e `endHour = 22`
/// liberam os horários de 8h, 9h, ..., 21h.
final class OpeningRange {
  const OpeningRange({
    required this.weekday,
    required this.startHour,
    required this.endHour,
  });

  factory OpeningRange.fromJson(JsonMap json) {
    return OpeningRange(
      weekday: json.readInt('weekday'),
      startHour: json.readInt('startHour'),
      endHour: json.readInt('endHour'),
    );
  }

  /// 0 = domingo ... 6 = sábado.
  final int weekday;
  final int startHour;
  final int endHour;

  /// Horas de início dos horários desta faixa.
  Iterable<int> get hours sync* {
    for (var hour = startHour; hour < endHour; hour++) {
      yield hour;
    }
  }

  JsonMap toJson() => {
    'weekday': weekday,
    'startHour': startHour,
    'endHour': endHour,
  };
}

/// Horário de funcionamento de uma quadra, válido a partir de [validFrom].
///
/// Mudar o horário cria uma nova vigência; reservas já feitas não somem
/// (ficam marcadas para realocação).
final class OpeningHours {
  const OpeningHours({required this.validFrom, required this.ranges});

  factory OpeningHours.fromJson(JsonMap json) {
    return OpeningHours(
      validFrom: json.readDate('validFrom'),
      ranges: [
        for (final range in json.readList('ranges'))
          OpeningRange.fromJson(range),
      ],
    );
  }

  final DateTime validFrom;
  final List<OpeningRange> ranges;

  /// Horas de início dos horários abertos no dia de [date].
  Set<int> hoursOn(DateTime date) {
    final weekday = apiWeekdayOf(date);
    return {
      for (final range in ranges)
        if (range.weekday == weekday) ...range.hours,
    };
  }

  JsonMap toJson() => {
    'validFrom': formatApiDate(validFrom),
    'ranges': [for (final range in ranges) range.toJson()],
  };
}

/// Resultado de salvar um novo horário de funcionamento.
final class OpeningHoursUpdate {
  const OpeningHoursUpdate({
    required this.openingHours,
    required this.affectedBookings,
  });

  factory OpeningHoursUpdate.fromJson(JsonMap json) {
    return OpeningHoursUpdate(
      openingHours: OpeningHours.fromJson(json.readMap('openingHours')),
      affectedBookings: json.readInt('affectedBookings'),
    );
  }

  final OpeningHours openingHours;

  /// Reservas confirmadas que ficaram fora do novo horário.
  final int affectedBookings;
}

/// Bloqueio pontual de uma quadra (manutenção, torneio).
final class ScheduleBlock {
  const ScheduleBlock({
    required this.id,
    required this.courtId,
    required this.startsAt,
    required this.endsAt,
    required this.reason,
  });

  factory ScheduleBlock.fromJson(JsonMap json) {
    return ScheduleBlock(
      id: json.readId('id'),
      courtId: json.readId('courtId'),
      startsAt: json.readDateTime('startsAt'),
      endsAt: json.readDateTime('endsAt'),
      reason: json.readString('reason'),
    );
  }

  final String id;
  final String courtId;
  final DateTime startsAt;
  final DateTime endsAt;
  final String reason;

  /// Se o horário de 1 hora que começa em [slotStart] toca o bloqueio.
  bool covers(DateTime slotStart) {
    final slotEnd = slotStart.add(const Duration(hours: 1));
    return slotStart.isBefore(endsAt) && slotEnd.isAfter(startsAt);
  }
}

/// Dados para criar um bloqueio.
final class ScheduleBlockInput {
  const ScheduleBlockInput({
    required this.startsAt,
    required this.endsAt,
    required this.reason,
  });

  final DateTime startsAt;
  final DateTime endsAt;
  final String reason;

  JsonMap toJson() => {
    'startsAt': formatApiDateTime(startsAt),
    'endsAt': formatApiDateTime(endsAt),
    'reason': reason.trim(),
  };
}
