import 'package:tennishub/core/network/json_reader.dart';

/// Situação de um horário de 1 hora numa quadra.
enum SlotStatus {
  /// Livre para reservar.
  free,

  /// Já reservado.
  busy,

  /// Fora do horário de funcionamento, bloqueado ou já passou.
  closed;

  static SlotStatus parse(String value) => switch (value) {
    'free' => SlotStatus.free,
    'busy' => SlotStatus.busy,
    'closed' => SlotStatus.closed,
    _ => throw FormatException('Situação de horário desconhecida: "$value".'),
  };
}

/// Um horário de 1 hora (RF02).
final class TimeSlot {
  const TimeSlot({required this.startsAt, required this.status});

  factory TimeSlot.fromJson(JsonMap json) {
    return TimeSlot(
      startsAt: json.readDateTime('startsAt'),
      status: SlotStatus.parse(json.readString('status')),
    );
  }

  final DateTime startsAt;
  final SlotStatus status;

  DateTime get endsAt => startsAt.add(const Duration(hours: 1));

  bool get isFree => status == SlotStatus.free;
}

/// Horários de uma quadra num dia.
final class CourtDaySchedule {
  const CourtDaySchedule({
    required this.courtId,
    required this.courtName,
    required this.slots,
    this.hourlyPriceCents,
  });

  factory CourtDaySchedule.fromJson(JsonMap json) {
    return CourtDaySchedule(
      courtId: json.readId('courtId'),
      courtName: json.readString('courtName'),
      hourlyPriceCents: json.readOptionalInt('hourlyPriceCents'),
      slots: [
        for (final slot in json.readList('slots')) TimeSlot.fromJson(slot),
      ],
    );
  }

  final String courtId;
  final String courtName;
  final int? hourlyPriceCents;
  final List<TimeSlot> slots;
}

/// Horários de todas as quadras num dia (RF01).
final class DayAvailability {
  const DayAvailability({required this.date, required this.courts});

  factory DayAvailability.fromJson(JsonMap json) {
    return DayAvailability(
      date: json.readDate('date'),
      courts: [
        for (final court in json.readList('courts'))
          CourtDaySchedule.fromJson(court),
      ],
    );
  }

  /// Dia consultado (sem hora).
  final DateTime date;
  final List<CourtDaySchedule> courts;

  /// Se existe ao menos um horário livre no dia.
  bool get hasFreeSlots =>
      courts.any((court) => court.slots.any((slot) => slot.isFree));
}
