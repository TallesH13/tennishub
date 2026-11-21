import 'package:tennishub/core/network/json_reader.dart';

/// Quadra do clube.
final class Court {
  const Court({
    required this.id,
    required this.name,
    this.hourlyPriceCents,
    this.unavailableFrom,
  });

  factory Court.fromJson(JsonMap json) {
    return Court(
      id: json.readId('id'),
      name: json.readString('name'),
      hourlyPriceCents: json.readOptionalInt('hourlyPriceCents'),
      unavailableFrom: json.readOptionalDate('unavailableFrom'),
    );
  }

  final String id;
  final String name;

  /// Valor por hora em centavos; `null` quando não cadastrado (D04).
  final int? hourlyPriceCents;

  /// A partir deste dia a quadra sai do sistema (remoção lógica, D11).
  final DateTime? unavailableFrom;

  /// Se a quadra aceita reservas no dia de [day].
  bool isAvailableOn(DateTime day) {
    final limit = unavailableFrom;
    return limit == null ||
        DateTime(day.year, day.month, day.day).isBefore(limit);
  }
}

/// Dados para cadastrar ou editar uma quadra.
final class CourtInput {
  const CourtInput({
    required this.name,
    this.hourlyPriceCents,
    this.unavailableFrom,
  });

  final String name;
  final int? hourlyPriceCents;
  final DateTime? unavailableFrom;

  JsonMap toJson() {
    final limit = unavailableFrom;
    return {
      'name': name.trim(),
      'hourlyPriceCents': hourlyPriceCents,
      'unavailableFrom': limit == null ? null : formatApiDate(limit),
    };
  }
}
