# Contrato da API

Formato das requisições e respostas da API REST do TennisHub, usado pelo app (issue #21) e pela API (issues #10 a #19).

| Situação | Endpoints |
|---|---|
| Implementado | Autenticação (`/api/auth/*`), `/api/health` |
| Proposto | Demais endpoints desta página. Mudanças devem ser combinadas aqui antes de implementadas. |

## Convenções

| Item | Regra |
|---|---|
| Prefixo | Todas as rotas ficam em `/api` |
| Formato | JSON em UTF-8, campos em camelCase |
| Identificadores | Número (`1`); o app aceita número ou texto |
| Data | `AAAA-MM-DD` (ex.: `2026-12-02`) |
| Data e hora | ISO 8601 com fuso (ex.: `2026-12-02T21:00:00.000Z`) |
| Dia da semana | `0` = domingo ... `6` = sábado |
| Valores | Centavos, inteiro (`8000` = R$ 80,00) |
| Telefone | Só dígitos, com DDD (`31987654321`) |
| Rotas do proprietário | Em `/api/owner/*`; exigem sessão |

## Autenticação (implementado)

A sessão vale 30 minutos de inatividade. A credencial é aceita no cookie `tennishub_session` (HttpOnly) ou no cabeçalho `Authorization: Bearer <token>`.

| Método | Rota | Corpo | Resposta |
|---|---|---|---|
| POST | `/api/auth/login` | `{ "email", "password" }` | `200 { "token", "expiresIn": 1800, "owner": { "id", "name", "email" } }` |
| GET | `/api/auth/me` | — | `200 { "owner": { "id", "name", "email" } }` |
| POST | `/api/auth/logout` | — | `204` |

## Erros

Todas as respostas de erro seguem o formato:

```json
{ "error": { "code": "SLOT_UNAVAILABLE", "message": "Esse horário acabou de ser reservado.", "details": [] } }
```

A `message` é mostrada ao usuário, então deve estar em português e dizer o que fazer.

| Status | `code` | Quando | Exceção no app |
|---|---|---|---|
| 401 | `UNAUTHORIZED` | Sem sessão, sessão expirada ou login recusado | `UnauthorizedException` / `InvalidCredentialsException` |
| 404 | `NOT_FOUND` | Recurso inexistente, ou código e telefone sem reserva | `NotFoundException` |
| 409 | `SLOT_UNAVAILABLE` | Horário reservado, fechado ou bloqueado | `SlotUnavailableException` |
| 409 | `DAILY_LIMIT_REACHED` | Telefone já tem 2 reservas no dia do jogo (RF03) | `DailyLimitException` |
| 409 | outro (ex.: `COURT_NAME_TAKEN`, `BOOKING_ALREADY_CANCELLED`, `CHANGE_DEADLINE_PASSED`, `BOOKING_ALREADY_STARTED`, `BOOKING_SAME_SLOT`) | Conflito com o estado atual | `ConflictException` |
| 422 | `VALIDATION_ERROR` | Dados inválidos; `details` = `[{ "field", "message" }]` | `ValidationException` |
| 429 | `TOO_MANY_ATTEMPTS` | Muitas tentativas de login, ou 10 tentativas sem achar a reserva em 15 minutos (por IP e por telefone) | `TooManyAttemptsException` |
| 5xx | `INTERNAL_ERROR` | Falha interna, sem detalhes | `ServerException` |

## Objetos

### Quadra

```json
{ "id": 1, "name": "Quadra 1", "hourlyPriceCents": 8000, "unavailableFrom": null }
```

`hourlyPriceCents` é opcional (D04). `unavailableFrom` marca a remoção lógica (D11).

### Reserva

```json
{
  "id": 42,
  "code": "K7M4QX9R",
  "courtId": 2,
  "courtName": "Quadra 2",
  "startsAt": "2026-12-02T21:00:00.000Z",
  "endsAt": "2026-12-02T22:00:00.000Z",
  "customerName": "Ana Paula Ribeiro",
  "customerPhone": "31987654321",
  "status": "confirmed",
  "needsRelocation": false,
  "relocationReason": null,
  "cancelledBy": null,
  "cancellationReason": null,
  "createdAt": "2026-11-30T14:12:09.000Z"
}
```

| Campo | Valores |
|---|---|
| `status` | `confirmed`, `cancelled` |
| `cancelledBy` | `customer`, `owner` ou `null` |
| `needsRelocation` | `true` quando a reserva ficou fora do horário de funcionamento |

## Área pública

| Método | Rota | Corpo | Resposta |
|---|---|---|---|
| GET | `/api/courts` | — | `200 { "courts": [Quadra] }`, só as ativas |
| GET | `/api/availability?date=AAAA-MM-DD` | — | `200` com os horários do dia (abaixo) |
| POST | `/api/bookings` | `{ "courtId", "startsAt", "customerName", "customerPhone" }` | `201 { "booking": Reserva }` |
| POST | `/api/bookings/lookup` | `{ "code", "phone" }` | `200 { "booking": Reserva }` |
| POST | `/api/bookings/cancel` | `{ "code", "phone" }` | `200 { "booking": Reserva }` |
| POST | `/api/bookings/reschedule` | `{ "code", "phone", "courtId", "startsAt" }` | `200 { "booking": Reserva }` |

Código e telefone vão no corpo, nunca na URL, para não ficarem em logs nem no histórico do navegador.

Resposta de `/api/availability`:

```json
{
  "date": "2026-12-02",
  "courts": [
    {
      "courtId": 1,
      "courtName": "Quadra 1",
      "hourlyPriceCents": 8000,
      "slots": [
        { "startsAt": "2026-12-02T10:00:00.000Z", "status": "free" },
        { "startsAt": "2026-12-02T11:00:00.000Z", "status": "busy" }
      ]
    }
  ]
}
```

| `status` do horário | Significado |
|---|---|
| `free` | Livre para reservar |
| `busy` | Reservado |
| `closed` | Fora do funcionamento, bloqueado ou já passou |

Todas as quadras do dia trazem os mesmos horários (a união dos horários abertos), para a grade ficar alinhada.

## Painel do proprietário

### Quadras

| Método | Rota | Corpo | Resposta |
|---|---|---|---|
| GET | `/api/owner/courts` | — | `200 { "courts": [Quadra] }`, inclusive as que vão sair |
| POST | `/api/owner/courts` | `{ "name", "hourlyPriceCents", "unavailableFrom" }` | `201 { "court": Quadra }` |
| PUT | `/api/owner/courts/:id` | `{ "name", "hourlyPriceCents", "unavailableFrom" }` | `200 { "court": Quadra }` |

### Horário de funcionamento e bloqueios

| Método | Rota | Corpo | Resposta |
|---|---|---|---|
| GET | `/api/owner/courts/:id/opening-hours` | — | `200 { "openingHours": { "validFrom", "ranges": [{ "weekday", "startHour", "endHour" }] } }` ou `{ "openingHours": null }` |
| POST | `/api/owner/courts/:id/opening-hours` | `{ "validFrom", "ranges": [...] }` | `200 { "openingHours": {...}, "affectedBookings": 2 }` |
| GET | `/api/owner/courts/:id/blocks` | — | `200 { "blocks": [{ "id", "courtId", "startsAt", "endsAt", "reason" }] }` |
| POST | `/api/owner/courts/:id/blocks` | `{ "startsAt", "endsAt", "reason" }` | `201 { "block": {...} }` |
| DELETE | `/api/owner/blocks/:id` | — | `204` |

Uma faixa `startHour: 8`, `endHour: 22` libera os horários de 8h a 21h. Salvar cria uma nova vigência a partir de `validFrom`; as reservas confirmadas que ficarem de fora recebem `needsRelocation: true` e entram em `affectedBookings`.

### Agendamentos

| Método | Rota | Corpo | Resposta |
|---|---|---|---|
| GET | `/api/owner/bookings?date=AAAA-MM-DD&courtId=&status=` | — | `200 { "bookings": [Reserva] }`, em ordem de horário |
| POST | `/api/owner/bookings/:id/relocate` | `{ "courtId", "startsAt", "reason" }` | `200 { "booking": Reserva }` |
| POST | `/api/owner/bookings/:id/cancel` | `{ "reason" }` | `200 { "booking": Reserva }` |

O motivo é obrigatório nas duas ações (`422` com `field: "reason"`).

### Relatório de locações (RF10)

| Método | Rota | Resposta |
|---|---|---|
| GET | `/api/owner/reports/rentals?from=&to=&courtId=&client=` | `200 { "rentals": [{ "id", "startsAt", "courtId", "courtName", "clientName", "clientPhone", "valueCents" }] }` |
| GET | `/api/owner/reports/rentals.pdf?from=&to=&courtId=&client=` | `200` com `application/pdf` |

`client` busca por parte do nome ou do telefone. Os totais são calculados no app a partir das locações.
