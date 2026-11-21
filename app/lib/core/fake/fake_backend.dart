import 'package:tennishub/core/network/api_exception.dart';
import 'package:tennishub/core/time/clock.dart';
import 'package:tennishub/features/bookings/domain/booking.dart';
import 'package:tennishub/features/courts/domain/availability.dart';
import 'package:tennishub/features/courts/domain/court.dart';
import 'package:tennishub/features/courts/domain/court_schedule.dart';

/// Simulação da API em memória, com as mesmas regras de negócio.
///
/// É compartilhada pelos repositórios falsos de quadras e reservas, para que
/// uma reserva feita numa tela apareça como ocupada na grade de horários.
/// Os erros são os mesmos `ApiException` que a API real gera.
///
/// Os dados de exemplo são gerados a partir de "hoje" ([clock]).
class FakeBackend {
  FakeBackend({Clock? clock, this.latency = Duration.zero})
    : _clock = clock ?? DateTime.now {
    _seed();
  }

  final Clock _clock;

  /// Espera simulada antes de cada resposta, para ver o estado de carregando.
  final Duration latency;

  /// Limite de reservas confirmadas por telefone no dia do jogo (RF03).
  static const int dailyLimit = 2;

  final List<Court> _courts = [];
  final Map<String, List<OpeningHours>> _openingHours = {};
  final List<ScheduleBlock> _blocks = [];
  final List<Booking> _bookings = [];
  int _nextId = 1;
  int _nextCode = 0;

  Future<void> wait() async {
    if (latency > Duration.zero) {
      await Future<void>.delayed(latency);
    }
  }

  // ---------------------------------------------------------------- quadras

  List<Court> courts({bool includeUnavailable = false}) {
    final today = _today();
    return [
      for (final court in _courts)
        if (includeUnavailable || court.isAvailableOn(today)) court,
    ];
  }

  Court createCourt(CourtInput input) {
    _validateCourt(input);
    final court = Court(
      id: _newId(),
      name: input.name.trim(),
      hourlyPriceCents: input.hourlyPriceCents,
      unavailableFrom: input.unavailableFrom,
    );
    _courts.add(court);
    return court;
  }

  Court updateCourt(String id, CourtInput input) {
    final index = _courts.indexWhere((court) => court.id == id);
    if (index < 0) {
      throw const NotFoundException('Quadra não encontrada.');
    }
    _validateCourt(input, ignoreId: id);
    final court = Court(
      id: id,
      name: input.name.trim(),
      hourlyPriceCents: input.hourlyPriceCents,
      unavailableFrom: input.unavailableFrom,
    );
    _courts[index] = court;
    return court;
  }

  void _validateCourt(CourtInput input, {String? ignoreId}) {
    final name = input.name.trim();
    if (name.isEmpty) {
      throw const ValidationException('Confira os dados informados.', {
        'name': 'Informe o nome da quadra.',
      });
    }
    final taken = courts().any(
      (court) =>
          court.id != ignoreId &&
          court.name.toLowerCase() == name.toLowerCase(),
    );
    if (taken) {
      throw const ConflictException(
        'Já existe uma quadra com esse nome.',
        code: 'COURT_NAME_TAKEN',
      );
    }
  }

  // ---------------------------------------------------- horário de funcionamento

  OpeningHours? openingHoursOn(String courtId, DateTime day) {
    final date = _dateOnly(day);
    OpeningHours? current;
    for (final version in _openingHours[courtId] ?? const <OpeningHours>[]) {
      final inForce = !version.validFrom.isAfter(date);
      if (inForce &&
          (current == null || version.validFrom.isAfter(current.validFrom))) {
        current = version;
      }
    }
    return current;
  }

  OpeningHoursUpdate saveOpeningHours(String courtId, OpeningHours hours) {
    _court(courtId);
    final invalid = hours.ranges.any(
      (range) =>
          range.weekday < 0 ||
          range.weekday > 6 ||
          range.startHour < 0 ||
          range.endHour > 24 ||
          range.startHour >= range.endHour,
    );
    if (invalid) {
      throw const ValidationException('Confira os dados informados.', {
        'ranges': 'O horário de fechamento deve ser depois do de abertura.',
      });
    }

    final versions = _openingHours.putIfAbsent(courtId, () => []);
    versions
      ..removeWhere(
        (version) => version.validFrom == _dateOnly(hours.validFrom),
      )
      ..add(hours);

    var affected = 0;
    for (var i = 0; i < _bookings.length; i++) {
      final booking = _bookings[i];
      final fromNewHours = !_dateOnly(booking.startsAt)
          .isBefore(_dateOnly(hours.validFrom));
      if (booking.courtId == courtId && booking.isConfirmed && fromNewHours) {
        final open = hours
            .hoursOn(booking.startsAt)
            .contains(booking.startsAt.hour);
        if (!open) {
          _bookings[i] = booking.copyWith(needsRelocation: true);
          affected++;
        }
      }
    }
    return OpeningHoursUpdate(openingHours: hours, affectedBookings: affected);
  }

  List<ScheduleBlock> blocks(String courtId) {
    final today = _today();
    return [
      for (final block in _blocks)
        if (block.courtId == courtId && block.endsAt.isAfter(today)) block,
    ]..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  }

  ScheduleBlock createBlock(String courtId, ScheduleBlockInput input) {
    _court(courtId);
    final errors = <String, String>{
      if (!input.endsAt.isAfter(input.startsAt))
        'endsAt': 'O fim do bloqueio deve ser depois do início.',
      if (input.reason.trim().isEmpty)
        'reason': 'Informe o motivo do bloqueio.',
    };
    if (errors.isNotEmpty) {
      throw ValidationException('Confira os dados informados.', errors);
    }
    final block = ScheduleBlock(
      id: _newId(),
      courtId: courtId,
      startsAt: input.startsAt,
      endsAt: input.endsAt,
      reason: input.reason.trim(),
    );
    _blocks.add(block);
    return block;
  }

  void deleteBlock(String blockId) {
    final before = _blocks.length;
    _blocks.removeWhere((block) => block.id == blockId);
    if (_blocks.length == before) {
      throw const NotFoundException('Bloqueio não encontrado.');
    }
  }

  // ----------------------------------------------------------- disponibilidade

  DayAvailability availability(DateTime day) {
    final date = _dateOnly(day);
    final openCourts = [
      for (final court in courts())
        if (court.isAvailableOn(date)) court,
    ];

    final allHours = <int>{
      for (final court in openCourts)
        ...?openingHoursOn(court.id, date)?.hoursOn(date),
    }.toList()..sort();

    return DayAvailability(
      date: date,
      courts: [
        for (final court in openCourts)
          CourtDaySchedule(
            courtId: court.id,
            courtName: court.name,
            hourlyPriceCents: court.hourlyPriceCents,
            slots: [
              for (final hour in allHours)
                TimeSlot(
                  startsAt: DateTime(date.year, date.month, date.day, hour),
                  status: _slotStatus(
                    court.id,
                    DateTime(date.year, date.month, date.day, hour),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  SlotStatus _slotStatus(
    String courtId,
    DateTime startsAt, {
    String? ignoreBookingId,
  }) {
    final opening = openingHoursOn(courtId, startsAt);
    final isOpen =
        opening != null && opening.hoursOn(startsAt).contains(startsAt.hour);
    final isBlocked = _blocks.any(
      (block) => block.courtId == courtId && block.covers(startsAt),
    );
    final isPast = !startsAt.isAfter(_clock());
    if (!isOpen || isBlocked || isPast) {
      return SlotStatus.closed;
    }
    final isTaken = _bookings.any(
      (booking) =>
          booking.id != ignoreBookingId &&
          booking.isConfirmed &&
          booking.courtId == courtId &&
          booking.startsAt == startsAt,
    );
    return isTaken ? SlotStatus.busy : SlotStatus.free;
  }

  // ------------------------------------------------------- reservas (cliente)

  Booking createBooking(BookingRequest request) {
    final name = request.customerName.trim();
    final phone = onlyDigits(request.customerPhone);
    final errors = <String, String>{
      if (name.length < 5 || name.length > 100)
        'customerName': 'Informe nome e sobrenome (mínimo de 5 letras).',
      if (!_validPhone.hasMatch(phone))
        'customerPhone':
            'Telefone inválido. Digite o DDD e o número, como (31) 98765-4321.',
    };
    if (errors.isNotEmpty) {
      throw ValidationException('Confira os dados informados.', errors);
    }

    final court = _court(request.courtId);
    _ensureFree(court.id, request.startsAt);
    _ensureDailyLimit(phone, request.startsAt);

    final booking = Booking(
      id: _newId(),
      code: _newCode(),
      courtId: court.id,
      courtName: court.name,
      startsAt: request.startsAt,
      customerName: name,
      customerPhone: phone,
      status: BookingStatus.confirmed,
    );
    _bookings.add(booking);
    return booking;
  }

  Booking findBooking(String code, String phone) {
    final normalizedCode = code.trim().toUpperCase();
    final digits = onlyDigits(phone);
    for (final booking in _bookings) {
      if (booking.code == normalizedCode && booking.customerPhone == digits) {
        return booking;
      }
    }
    throw const NotFoundException(
      'Não encontramos uma reserva com esse código e telefone.',
    );
  }

  Booking cancelByCustomer(String code, String phone) {
    final booking = _confirmed(findBooking(code, phone));
    return _replace(
      booking.copyWith(
        status: BookingStatus.cancelled,
        cancelledBy: CancelledBy.customer,
      ),
    );
  }

  Booking reschedule(
    String code,
    String phone, {
    required String courtId,
    required DateTime startsAt,
  }) {
    final booking = _confirmed(findBooking(code, phone));
    final court = _court(courtId);
    _ensureFree(court.id, startsAt, ignoreBookingId: booking.id);
    _ensureDailyLimit(
      booking.customerPhone,
      startsAt,
      ignoreBookingId: booking.id,
    );
    return _replace(
      booking.copyWith(
        courtId: court.id,
        courtName: court.name,
        startsAt: startsAt,
        needsRelocation: false,
      ),
    );
  }

  // -------------------------------------------------------- reservas (painel)

  List<Booking> ownerBookings(BookingQuery query) {
    final date = _dateOnly(query.date);
    return [
      for (final booking in _bookings)
        if (_dateOnly(booking.startsAt) == date &&
            (query.courtId == null || booking.courtId == query.courtId) &&
            (query.status == null || booking.status == query.status))
          booking,
    ]..sort((a, b) {
      final byTime = a.startsAt.compareTo(b.startsAt);
      return byTime != 0 ? byTime : a.courtName.compareTo(b.courtName);
    });
  }

  Booking relocate(
    String bookingId, {
    required String courtId,
    required DateTime startsAt,
    required String reason,
  }) {
    if (reason.trim().isEmpty) {
      throw const ValidationException('Confira os dados informados.', {
        'reason': 'Informe o motivo da realocação.',
      });
    }
    final booking = _confirmed(_bookingById(bookingId));
    final court = _court(courtId);
    _ensureFree(court.id, startsAt, ignoreBookingId: booking.id);
    return _replace(
      booking.copyWith(
        courtId: court.id,
        courtName: court.name,
        startsAt: startsAt,
        needsRelocation: false,
        relocationReason: reason.trim(),
      ),
    );
  }

  Booking cancelByOwner(String bookingId, {required String reason}) {
    if (reason.trim().isEmpty) {
      throw const ValidationException('Confira os dados informados.', {
        'reason': 'Informe o motivo do cancelamento.',
      });
    }
    final booking = _confirmed(_bookingById(bookingId));
    return _replace(
      booking.copyWith(
        status: BookingStatus.cancelled,
        cancelledBy: CancelledBy.owner,
        cancellationReason: reason.trim(),
      ),
    );
  }

  // ------------------------------------------------------------------ apoio

  static final RegExp _validPhone = RegExp(r'^[1-9][1-9][0-9]{8,9}$');
  static const String _codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  DateTime _today() => _dateOnly(_clock());

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  String _newId() => '${_nextId++}';

  /// Código de 8 caracteres sem 0, O, 1 e I (D06), único na memória.
  String _newCode() {
    while (true) {
      var seed = (_nextCode++ * 2654435761 + 97) & 0x7fffffff;
      final buffer = StringBuffer();
      for (var i = 0; i < 8; i++) {
        buffer.write(_codeAlphabet[seed % _codeAlphabet.length]);
        seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      }
      final code = buffer.toString();
      if (!_bookings.any((booking) => booking.code == code)) {
        return code;
      }
    }
  }

  Court _court(String courtId) {
    for (final court in _courts) {
      if (court.id == courtId) {
        return court;
      }
    }
    throw const NotFoundException('Quadra não encontrada.');
  }

  Booking _bookingById(String bookingId) {
    for (final booking in _bookings) {
      if (booking.id == bookingId) {
        return booking;
      }
    }
    throw const NotFoundException('Agendamento não encontrado.');
  }

  Booking _confirmed(Booking booking) {
    if (!booking.isConfirmed) {
      throw const ConflictException(
        'Esta reserva já foi cancelada.',
        code: 'BOOKING_ALREADY_CANCELLED',
      );
    }
    return booking;
  }

  void _ensureFree(
    String courtId,
    DateTime startsAt, {
    String? ignoreBookingId,
  }) {
    if (_slotStatus(courtId, startsAt, ignoreBookingId: ignoreBookingId) !=
        SlotStatus.free) {
      throw const SlotUnavailableException();
    }
  }

  void _ensureDailyLimit(
    String phone,
    DateTime startsAt, {
    String? ignoreBookingId,
  }) {
    final day = _dateOnly(startsAt);
    final count = _bookings
        .where(
          (booking) =>
              booking.id != ignoreBookingId &&
              booking.isConfirmed &&
              booking.customerPhone == phone &&
              _dateOnly(booking.startsAt) == day,
        )
        .length;
    if (count >= dailyLimit) {
      throw const DailyLimitException();
    }
  }

  Booking _replace(Booking updated) {
    final index = _bookings.indexWhere((booking) => booking.id == updated.id);
    _bookings[index] = updated;
    return updated;
  }

  void _seed() {
    final today = _today();
    DateTime day(int offset) =>
        DateTime(today.year, today.month, today.day + offset);

    final court1 = createCourt(
      const CourtInput(name: 'Quadra 1', hourlyPriceCents: 8000),
    );
    final court2 = createCourt(
      const CourtInput(name: 'Quadra 2', hourlyPriceCents: 8000),
    );
    final central = createCourt(
      const CourtInput(name: 'Quadra Central', hourlyPriceCents: 12000),
    );
    createCourt(
      CourtInput(
        name: 'Quadra 4',
        hourlyPriceCents: 7000,
        unavailableFrom: day(24),
      ),
    );

    const weekdays = [1, 2, 3, 4, 5];
    for (final court in _courts) {
      _openingHours[court.id] = [
        OpeningHours(
          validFrom: day(-30),
          ranges: [
            for (final weekday in weekdays)
              OpeningRange(weekday: weekday, startHour: 7, endHour: 22),
            const OpeningRange(weekday: 6, startHour: 8, endHour: 18),
            if (court.id == central.id)
              const OpeningRange(weekday: 0, startHour: 8, endHour: 14),
          ],
        ),
      ];
    }

    _blocks.add(
      ScheduleBlock(
        id: _newId(),
        courtId: court2.id,
        startsAt: DateTime(day(3).year, day(3).month, day(3).day, 8),
        endsAt: DateTime(day(3).year, day(3).month, day(3).day, 12),
        reason: 'Manutenção do piso',
      ),
    );

    const customers = [
      ('Ana Paula Ribeiro', '31987654321'),
      ('Marcos Vinícius Lopes', '31998123044'),
      ('Juliana Andrade', '31984551290'),
      ('Rafael Couto', '31991076583'),
      ('Pedro Henrique Alves', '31996342218'),
      ('Beatriz Nogueira', '31983905516'),
    ];
    final seedBookings = [
      (court1, 1, 18, 0),
      (court1, 1, 19, 1),
      (court2, 1, 19, 2),
      (central, 1, 18, 3),
      (court2, 2, 9, 4),
      (court1, 2, 20, 5),
      (central, 3, 10, 0),
      (court2, 3, 17, 1),
    ];
    for (final (court, offset, hour, customer) in seedBookings) {
      final date = day(offset);
      final (name, phone) = customers[customer];
      _bookings.add(
        Booking(
          id: _newId(),
          code: _newCode(),
          courtId: court.id,
          courtName: court.name,
          startsAt: DateTime(date.year, date.month, date.day, hour),
          customerName: name,
          customerPhone: phone,
          status: BookingStatus.confirmed,
        ),
      );
    }
  }
}
