-- Up Migration

CREATE TABLE bookings (
  id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  court_id            bigint      NOT NULL REFERENCES courts (id) ON DELETE RESTRICT,
  starts_at           timestamptz NOT NULL,
  ends_at             timestamptz NOT NULL,
  -- Dia do jogo no fuso de São Paulo (D01): base do limite de 2 reservas por dia (RF03).
  game_date           date GENERATED ALWAYS AS ((starts_at AT TIME ZONE 'America/Sao_Paulo')::date) STORED,
  customer_name       text        NOT NULL,
  -- Só dígitos (D07): DDD sem zero + 8 ou 9 dígitos.
  customer_phone      text        NOT NULL,
  -- D06: 8 caracteres, sem 0/O/1/I.
  code                text        NOT NULL,
  status              text        NOT NULL DEFAULT 'confirmed',
  relocation_reason   text,
  cancelled_at        timestamptz,
  cancelled_by        text,
  cancellation_reason text,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT bookings_code_key UNIQUE (code),
  CONSTRAINT bookings_code_format CHECK (code ~ '^[A-HJ-NP-Z2-9]{8}$'),
  CONSTRAINT bookings_customer_name_length CHECK (char_length(btrim(customer_name)) BETWEEN 5 AND 100),
  CONSTRAINT bookings_customer_phone_digits CHECK (customer_phone ~ '^[1-9][1-9][0-9]{8,9}$'),
  CONSTRAINT bookings_status_valid CHECK (status IN ('confirmed', 'cancelled')),
  -- Exatamente 1 hora (RF02).
  CONSTRAINT bookings_one_hour CHECK (ends_at = starts_at + interval '1 hour'),
  -- Início em hora cheia no horário de São Paulo.
  CONSTRAINT bookings_starts_on_the_hour
    CHECK (date_trunc('hour', starts_at, 'America/Sao_Paulo') = starts_at),
  -- Reserva cancelada sempre registra quando e por quem; confirmada nunca.
  CONSTRAINT bookings_cancellation_consistent CHECK (
    (status = 'cancelled' AND cancelled_at IS NOT NULL AND cancelled_by IN ('customer', 'owner'))
    OR (status = 'confirmed' AND cancelled_at IS NULL AND cancelled_by IS NULL)
  )
);

-- RNF01: no máximo uma reserva confirmada por quadra e início.
-- Canceladas ficam fora do índice, liberando o horário.
CREATE UNIQUE INDEX bookings_court_slot_confirmed_key ON bookings (court_id, starts_at)
  WHERE status = 'confirmed';

-- Contagem do limite diário (RF03) por telefone e dia do jogo.
CREATE INDEX bookings_phone_game_date_confirmed_idx ON bookings (customer_phone, game_date)
  WHERE status = 'confirmed';

-- Consultas do proprietário por período (RF08, RF10).
CREATE INDEX bookings_starts_at_idx ON bookings (starts_at);

CREATE TRIGGER bookings_set_updated_at BEFORE UPDATE ON bookings
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Down Migration

DROP TABLE bookings;
