import 'package:tennishub/core/network/json_reader.dart';

/// Situação de uma reserva.
enum BookingStatus {
  confirmed,
  cancelled;

  static BookingStatus parse(String value) => switch (value) {
    'confirmed' => BookingStatus.confirmed,
    'cancelled' => BookingStatus.cancelled,
    _ => throw FormatException('Situação de reserva desconhecida: "$value".'),
  };
}

/// Quem cancelou a reserva.
enum CancelledBy {
  customer,
  owner;

  static CancelledBy parse(String value) => switch (value) {
    'customer' => CancelledBy.customer,
    'owner' => CancelledBy.owner,
    _ => throw FormatException('Autor de cancelamento desconhecido: "$value".'),
  };
}

/// Reserva de 1 hora numa quadra.
final class Booking {
  const Booking({
    required this.id,
    required this.code,
    required this.courtId,
    required this.courtName,
    required this.startsAt,
    required this.customerName,
    required this.customerPhone,
    required this.status,
    this.needsRelocation = false,
    this.relocationReason,
    this.cancelledBy,
    this.cancellationReason,
  });

  factory Booking.fromJson(JsonMap json) {
    final cancelledBy = json.readOptionalString('cancelledBy');
    return Booking(
      id: json.readId('id'),
      code: json.readString('code'),
      courtId: json.readId('courtId'),
      courtName: json.readString('courtName'),
      startsAt: json.readDateTime('startsAt'),
      customerName: json.readString('customerName'),
      customerPhone: json.readString('customerPhone'),
      status: BookingStatus.parse(json.readString('status')),
      needsRelocation: json.readBool('needsRelocation'),
      relocationReason: json.readOptionalString('relocationReason'),
      cancelledBy: cancelledBy == null ? null : CancelledBy.parse(cancelledBy),
      cancellationReason: json.readOptionalString('cancellationReason'),
    );
  }

  final String id;

  /// Código de 8 caracteres usado pelo cliente para cancelar ou remarcar (D06).
  final String code;

  final String courtId;
  final String courtName;
  final DateTime startsAt;
  final String customerName;

  /// Só os dígitos, com DDD (D07).
  final String customerPhone;

  final BookingStatus status;

  /// A reserva ficou fora do horário de funcionamento e precisa ser realocada.
  final bool needsRelocation;

  final String? relocationReason;
  final CancelledBy? cancelledBy;
  final String? cancellationReason;

  DateTime get endsAt => startsAt.add(const Duration(hours: 1));

  bool get isConfirmed => status == BookingStatus.confirmed;

  Booking copyWith({
    String? courtId,
    String? courtName,
    DateTime? startsAt,
    BookingStatus? status,
    bool? needsRelocation,
    String? relocationReason,
    CancelledBy? cancelledBy,
    String? cancellationReason,
  }) {
    return Booking(
      id: id,
      code: code,
      courtId: courtId ?? this.courtId,
      courtName: courtName ?? this.courtName,
      startsAt: startsAt ?? this.startsAt,
      customerName: customerName,
      customerPhone: customerPhone,
      status: status ?? this.status,
      needsRelocation: needsRelocation ?? this.needsRelocation,
      relocationReason: relocationReason ?? this.relocationReason,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      cancellationReason: cancellationReason ?? this.cancellationReason,
    );
  }
}

/// Pedido de reserva feito pelo cliente (RF02).
final class BookingRequest {
  const BookingRequest({
    required this.courtId,
    required this.startsAt,
    required this.customerName,
    required this.customerPhone,
  });

  final String courtId;
  final DateTime startsAt;
  final String customerName;

  /// Pode vir com máscara; só os dígitos são enviados.
  final String customerPhone;

  JsonMap toJson() => {
    'courtId': courtId,
    'startsAt': formatApiDateTime(startsAt),
    'customerName': customerName.trim(),
    'customerPhone': onlyDigits(customerPhone),
  };
}

/// Filtros da lista de agendamentos do painel (RF08).
final class BookingQuery {
  const BookingQuery({required this.date, this.courtId, this.status});

  final DateTime date;
  final String? courtId;
  final BookingStatus? status;

  Map<String, String?> toQuery() => {
    'date': formatApiDate(date),
    'courtId': courtId,
    'status': status?.name,
  };
}

/// Remove tudo que não é dígito (ex.: máscara de telefone).
String onlyDigits(String value) => value.replaceAll(RegExp(r'\D'), '');
