-- Up Migration

-- Fuso padrão das novas conexões. As regras de "dia" não dependem dele:
-- usam o fuso explícito 'America/Sao_Paulo' nas colunas e restrições.
DO $$
BEGIN
  EXECUTE format('ALTER DATABASE %I SET timezone TO %L', current_database(), 'America/Sao_Paulo');
END
$$;

-- Necessária para as restrições de exclusão (faixas de horário sobrepostas).
CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE FUNCTION set_updated_at() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END
$$;

-- Proprietário: criado só pelo seed (D09), sem tela de cadastro.
CREATE TABLE owners (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name          text        NOT NULL,
  email         text        NOT NULL,
  password_hash text        NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT owners_name_length CHECK (char_length(btrim(name)) BETWEEN 2 AND 100),
  CONSTRAINT owners_email_format CHECK (email ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'),
  -- Hash do bcrypt tem 60 caracteres; impede gravar senha em texto puro por engano.
  CONSTRAINT owners_password_hash_length CHECK (char_length(password_hash) >= 50)
);

-- E-mail único sem diferenciar maiúsculas.
CREATE UNIQUE INDEX owners_email_key ON owners (lower(email));

CREATE TRIGGER owners_set_updated_at BEFORE UPDATE ON owners
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE courts (
  id               bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name             text          NOT NULL,
  -- Opcional (D04): o relatório só soma valor quando ele existe.
  hourly_price     numeric(10,2),
  -- Remoção lógica (D11): a quadra deixa de estar disponível a partir desta data.
  unavailable_from date,
  created_at       timestamptz   NOT NULL DEFAULT now(),
  updated_at       timestamptz   NOT NULL DEFAULT now(),
  CONSTRAINT courts_name_length CHECK (char_length(btrim(name)) BETWEEN 2 AND 60),
  CONSTRAINT courts_hourly_price_non_negative CHECK (hourly_price IS NULL OR hourly_price >= 0)
);

-- Nome único entre as quadras não removidas, sem diferenciar maiúsculas.
CREATE UNIQUE INDEX courts_active_name_key ON courts (lower(btrim(name)))
  WHERE unavailable_from IS NULL;

CREATE TRIGGER courts_set_updated_at BEFORE UPDATE ON courts
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Down Migration

DROP TABLE courts;
DROP TABLE owners;
DROP FUNCTION set_updated_at();
DROP EXTENSION IF EXISTS btree_gist;
DO $$
BEGIN
  EXECUTE format('ALTER DATABASE %I RESET timezone', current_database());
END
$$;
