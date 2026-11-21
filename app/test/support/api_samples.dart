/// Amostras de respostas da API usadas nos testes.
///
/// As de autenticação seguem as respostas reais da API (testes de integração
/// em `api/test/integration/auth.test.ts` e mensagens de `api/src`). As demais
/// seguem o contrato de `docs/api.md` e devem ser trocadas por respostas reais
/// quando os endpoints forem entregues.
library;

// ------------------------------------------------- autenticação (API real)

const String sampleToken = 'b3f1c2d4e5a6978812345678abcdef00';

const Map<String, Object?> loginResponse = {
  'token': sampleToken,
  'expiresIn': 1800,
  'owner': {
    'id': 1,
    'name': 'Proprietário TennisHub',
    'email': 'proprietario@tennishub.com',
  },
};

const Map<String, Object?> meResponse = {
  'owner': {
    'id': 1,
    'name': 'Proprietário TennisHub',
    'email': 'proprietario@tennishub.com',
  },
};

const Map<String, Object?> invalidCredentialsError = {
  'error': {'code': 'UNAUTHORIZED', 'message': 'E-mail ou senha inválidos.'},
};

const Map<String, Object?> sessionExpiredError = {
  'error': {
    'code': 'UNAUTHORIZED',
    'message': 'Sessão expirada por inatividade. Faça login novamente.',
  },
};

const Map<String, Object?> tooManyAttemptsError = {
  'error': {
    'code': 'TOO_MANY_ATTEMPTS',
    'message':
        'Muitas tentativas de login falhas. Tente novamente em 15 minutos.',
  },
};

const Map<String, Object?> validationError = {
  'error': {
    'code': 'VALIDATION_ERROR',
    'message': 'Dados inválidos.',
    'details': [
      {'field': 'customerPhone', 'message': 'Telefone inválido.'},
      {'field': 'customerName', 'message': 'Informe nome e sobrenome.'},
    ],
  },
};

const Map<String, Object?> internalError = {
  'error': {'code': 'INTERNAL_ERROR', 'message': 'Erro interno do servidor.'},
};

// ------------------------------------------------ contrato (docs/api.md)

const Map<String, Object?> slotUnavailableError = {
  'error': {
    'code': 'SLOT_UNAVAILABLE',
    'message': 'Esse horário acabou de ser reservado.',
  },
};

const Map<String, Object?> dailyLimitError = {
  'error': {
    'code': 'DAILY_LIMIT_REACHED',
    'message': 'Este telefone já tem 2 reservas para 02/12/2026.',
  },
};

const Map<String, Object?> bookingNotFoundError = {
  'error': {
    'code': 'NOT_FOUND',
    'message': 'Não encontramos uma reserva com esse código e telefone.',
  },
};

const Map<String, Object?> bookingJson = {
  'id': 42,
  'code': 'K7M4QX9R',
  'courtId': 2,
  'courtName': 'Quadra 2',
  'startsAt': '2026-12-02T21:00:00.000Z',
  'endsAt': '2026-12-02T22:00:00.000Z',
  'customerName': 'Ana Paula Ribeiro',
  'customerPhone': '31987654321',
  'status': 'confirmed',
  'needsRelocation': false,
  'relocationReason': null,
  'cancelledBy': null,
  'cancellationReason': null,
  'createdAt': '2026-11-30T14:12:09.000Z',
};

final Map<String, Object?> cancelledBookingJson = {
  ...bookingJson,
  'status': 'cancelled',
  'cancelledBy': 'customer',
};

const Map<String, Object?> courtsResponse = {
  'courts': [
    {
      'id': 1,
      'name': 'Quadra 1',
      'hourlyPriceCents': 8000,
      'unavailableFrom': null,
    },
    {
      'id': 4,
      'name': 'Quadra 4',
      'hourlyPriceCents': null,
      'unavailableFrom': '2026-12-15',
    },
  ],
};

const Map<String, Object?> availabilityResponse = {
  'date': '2026-12-02',
  'courts': [
    {
      'courtId': 1,
      'courtName': 'Quadra 1',
      'hourlyPriceCents': 8000,
      'slots': [
        {'startsAt': '2026-12-02T10:00:00.000Z', 'status': 'closed'},
        {'startsAt': '2026-12-02T11:00:00.000Z', 'status': 'free'},
        {'startsAt': '2026-12-02T12:00:00.000Z', 'status': 'busy'},
      ],
    },
  ],
};

const Map<String, Object?> openingHoursUpdateResponse = {
  'openingHours': {
    'validFrom': '2026-12-01',
    'ranges': [
      {'weekday': 1, 'startHour': 7, 'endHour': 22},
      {'weekday': 6, 'startHour': 8, 'endHour': 18},
    ],
  },
  'affectedBookings': 2,
};

const Map<String, Object?> rentalsResponse = {
  'rentals': [
    {
      'id': 7,
      'startsAt': '2026-11-03T21:00:00.000Z',
      'courtId': 1,
      'courtName': 'Quadra 1',
      'clientName': 'Ana Paula Ribeiro',
      'clientPhone': '31987654321',
      'valueCents': 8000,
    },
    {
      'id': 9,
      'startsAt': '2026-11-04T13:00:00.000Z',
      'courtId': 2,
      'courtName': 'Quadra 2',
      'clientName': 'Rafael Couto',
      'clientPhone': '31991076583',
      'valueCents': null,
    },
  ],
};
