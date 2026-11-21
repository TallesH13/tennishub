-- Up Migration

-- Faixas de funcionamento por dia da semana (RF07, #12).
-- Uma "vigência" é o conjunto de faixas de uma quadra com o mesmo valid_from.
-- Para uma data D, vale a vigência de maior valid_from <= D.
CREATE TABLE availability_rules (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  court_id    bigint      NOT NULL REFERENCES courts (id) ON DELETE CASCADE,
  -- 0 = domingo ... 6 = sábado (igual a EXTRACT(DOW ...)).
  weekday     smallint    NOT NULL,
  -- Horas cheias: a faixa 8 a 22 gera os horários 8h, 9h, ..., 21h.
  start_hour  smallint    NOT NULL,
  end_hour    smallint    NOT NULL,
  valid_from  date        NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT availability_rules_weekday_range CHECK (weekday BETWEEN 0 AND 6),
  CONSTRAINT availability_rules_start_hour_range CHECK (start_hour BETWEEN 0 AND 23),
  CONSTRAINT availability_rules_end_hour_range CHECK (end_hour BETWEEN 1 AND 24),
  CONSTRAINT availability_rules_end_after_start CHECK (end_hour > start_hour),
  -- Faixas sobrepostas da mesma quadra, dia e vigência são rejeitadas.
  CONSTRAINT availability_rules_no_overlap EXCLUDE USING gist (
    court_id WITH =,
    weekday WITH =,
    valid_from WITH =,
    int4range(start_hour, end_hour) WITH &&
  )
);

CREATE INDEX availability_rules_court_valid_from_idx ON availability_rules (court_id, valid_from);

-- Bloqueios pontuais (ex.: manutenção) sem apagar a regra (#12).
CREATE TABLE schedule_blocks (
  id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  court_id   bigint      NOT NULL REFERENCES courts (id) ON DELETE CASCADE,
  starts_at  timestamptz NOT NULL,
  ends_at    timestamptz NOT NULL,
  reason     text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT schedule_blocks_end_after_start CHECK (ends_at > starts_at)
);

CREATE INDEX schedule_blocks_court_period_idx ON schedule_blocks (court_id, starts_at, ends_at);

-- Down Migration

DROP TABLE schedule_blocks;
DROP TABLE availability_rules;
