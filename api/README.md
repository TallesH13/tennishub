# TennisHub — API

API REST do TennisHub em **Node.js 24 + TypeScript (modo estrito)**, com **Fastify**, **PostgreSQL** (`pg` + `node-pg-migrate`), validação com **Zod** e testes com **Vitest + Supertest**. As decisões de ferramentas estão na issue #4.

## Pré-requisitos

- Node.js 24 e npm
- PostgreSQL 16 local (para os testes e como plano B da apresentação)
- Uma branch própria no Neon (banco de desenvolvimento)

## Configuração

```bash
cd api
npm install
cp .env.example .env        # preencha com a sua branch do Neon
```

| Variável                                        | Obrigatória | Para que serve                                                                                                                                          |
| ----------------------------------------------- | ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `DATABASE_URL`                                  | sim         | Conexão usada pela API. No Neon, a string do **pooler** (host com `-pooler`).                                                                           |
| `DATABASE_URL_DIRECT`                           | com Neon    | Conexão **direta** do Neon, usada pelas migrations e pelo seed. Obrigatória quando a `DATABASE_URL` usa o pooler; no PostgreSQL local pode ficar vazia. |
| `SESSION_SECRET`                                | sim         | Segredo da sessão do proprietário (mínimo 32 caracteres).                                                                                               |
| `PORT` / `HOST`                                 | não         | Padrão `3000` / `127.0.0.1`.                                                                                                                            |
| `LOG_LEVEL`                                     | não         | Padrão `info`.                                                                                                                                          |
| `OWNER_NAME` / `OWNER_EMAIL` / `OWNER_PASSWORD` | só no seed  | Proprietário criado pelo `npm run seed` (D09). A senha é gravada em hash (bcrypt).                                                                      |

O `.env` nunca vai para o Git. Strings de conexão só ficam em variáveis de ambiente (D16).

### Conectando ao Neon

1. No [console do Neon](https://console.neon.tech), abra o projeto do grupo e crie **uma branch para você** (Branches > New branch). Cada integrante usa a própria branch, para ninguém apagar os dados do outro.
2. Na sua branch, clique em **Connect**:
   - com **Connection pooling** ligado, copie a string para `DATABASE_URL` (o host termina em `-pooler`);
   - com **Connection pooling** desligado, copie a string para `DATABASE_URL_DIRECT`.
3. Cole as strings como o Neon gera, com `sslmode=require&channel_binding=require`. A API liga o TLS sozinha para qualquer host `*.neon.tech` e valida o certificado.

Por que duas conexões: o pooler do Neon (PgBouncer em modo transação) aguenta muitas conexões da API, mas não mantém estado de sessão. As migrations precisam da conexão direta, e a API recusa rodá-las pelo pooler. As travas de concorrência das reservas rodam sempre dentro de transação (`pg_advisory_xact_lock`), o que funciona no pooler (D16).

No plano gratuito, o Neon "dorme" depois de alguns minutos sem uso e a primeira consulta leva alguns segundos (D17). A API espera até 15 s pela conexão. Antes da apresentação e das medições de desempenho, acorde o banco com `GET /api/health`.

Sem internet, o plano B é o PostgreSQL local: troque a `DATABASE_URL` por `postgres://postgres:postgres@localhost:5432/tennishub` e deixe a `DATABASE_URL_DIRECT` vazia.

### Primeira execução no seu banco

```bash
npm run migrate   # cria as tabelas (usa a conexão direta do Neon)
npm run seed      # cria o proprietário e, se o banco estiver vazio, quadras, horários e 2 reservas de exemplo
npm run dev
```

O seed pode ser rodado de novo: ele atualiza o proprietário (inclusive a senha) e não duplica quadras. O modelo de dados está em [`docs/modelo-de-dados.md`](../docs/modelo-de-dados.md).

### Banco de teste local

Os testes leem o `api/.env` e usam a variável `TEST_DATABASE_URL`, nunca o banco da API. Por segurança, **só rodam em bancos cujo nome termina em `_test`**, porque apagam e recriam o schema a cada execução.

Duas formas de ter esse banco:

- **Neon:** na sua branch, crie o banco `tennishub_test` (Databases > New database) e use a string da **conexão direta** (sem `-pooler`), porque os testes rodam migrations.
- **Local:** `createdb tennishub_test` e `TEST_DATABASE_URL=postgres://postgres:postgres@localhost:5432/tennishub_test`.

No CI não há `.env`: o banco `tennishub_test` sobe como serviço do job e chega pela `DATABASE_URL`.

## Scripts

| Comando                    | O que faz                                                                  |
| -------------------------- | -------------------------------------------------------------------------- |
| `npm run dev`              | Sobe a API em modo de desenvolvimento, recarregando a cada alteração.      |
| `npm run build`            | Compila o TypeScript para `dist/`.                                         |
| `npm start`                | Roda a versão compilada (`dist/server.js`).                                |
| `npm run lint`             | ESLint + verificação de formatação do Prettier.                            |
| `npm run format`           | Formata o código com o Prettier.                                           |
| `npm run typecheck`        | Checa os tipos sem gerar arquivos.                                         |
| `npm test`                 | Roda todos os testes (unidade e integração). É o que o CI executa.         |
| `npm run test:unit`        | Só os testes de unidade, sem banco de dados.                               |
| `npm run test:integration` | Só os testes de integração; exige a `TEST_DATABASE_URL`.                   |
| `npm run migrate`          | Aplica as migrations pendentes (usa `DATABASE_URL_DIRECT`).                |
| `npm run migrate:down`     | Desfaz a última migration.                                                 |
| `npm run seed`             | Cria/atualiza o proprietário a partir do `.env` e insere dados de exemplo. |

Antes de abrir um PR: `npm run lint && npm run typecheck && npm test`. Sem banco de teste configurado, rode `npm run test:unit`; a integração roda no CI.

## Estrutura

```
src/
  app.ts            monta o Fastify (sem abrir porta), registra erros e rotas em /api
  server.ts         ponto de entrada: lê o .env, cria o pool e sobe o servidor
  config/env.ts     validação das variáveis de ambiente com Zod
  db/               pool, transação, runner das migrations e seed
  shared/errors.ts  erros de negócio e tratamento centralizado
  modules/<assunto>/
    *.routes.ts       camada HTTP (entrada e saída)
    *.service.ts      regras de negócio
    *.repository.ts   acesso a dados (SQL)
migrations/         migrations do banco (node-pg-migrate)
test/
  unit/             testes sem banco
  integration/      testes com PostgreSQL real
```

## Formato de erro

Todos os erros saem no mesmo formato JSON:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Dados inválidos.",
    "details": [{ "field": "phone", "message": "..." }]
  }
}
```

| Situação                         | Status      | `code`                                      |
| -------------------------------- | ----------- | ------------------------------------------- |
| Erro de negócio (`AppError`)     | o informado | o informado (ex.: `SLOT_TAKEN`)             |
| Validação (Zod)                  | 422         | `VALIDATION_ERROR`, com `details` por campo |
| Rota inexistente                 | 404         | `NOT_FOUND`                                 |
| Banco fora do ar no health check | 503         | `DATABASE_UNAVAILABLE`                      |
| Erro inesperado                  | 500         | `INTERNAL_ERROR` (sem detalhes internos)    |

## Endpoints

Todas as rotas ficam sob o prefixo `/api`.

Nas consultas públicas de horários (#13), data inválida ou ausente responde `400`, e datas fora da janela de reserva (de hoje até `BOOKING_WINDOW_DAYS` dias à frente, padrão 30, D08) devolvem listas vazias.

| Método   | Rota                                  | Descrição                                                                                                                                                                                                                                                                                                                                                                                                                   |
| -------- | ------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `GET`    | `/api/health`                         | `200 { "status": "ok", "database": "ok" }` quando a API e o banco respondem; `503` se o banco estiver indisponível.                                                                                                                                                                                                                                                                                                         |
| `POST`   | `/api/auth/login`                     | Autentica o proprietário com `{ "email", "password" }`, retorna `{ "token", "expiresIn", "owner" }` e grava cookie `HttpOnly` (`tennishub_session`). Bloqueia após 5 falhas em 15 minutos (`429`).                                                                                                                                                                                                                          |
| `POST`   | `/api/auth/logout`                    | Encerra a sessão atual do proprietário (`204 No Content`) e limpa o cookie de sessão. Exige sessão válida (`401`).                                                                                                                                                                                                                                                                                                          |
| `GET`    | `/api/auth/me`                        | Retorna `{ "owner": { "id", "name", "email" } }` do proprietário autenticado (`200`) ou `401` sem sessão válida.                                                                                                                                                                                                                                                                                                            |
| `GET`    | `/api/owner/me`                       | Alias protegido sob `/api/owner/*` que retorna os dados do proprietário autenticado (`200`). Todas as rotas `/api/owner/*` exigem sessão válida e expiram após 30 minutos de inatividade (`401`).                                                                                                                                                                                                                           |
| `GET`    | `/api/courts`                         | Lista as quadras ativas (`200 { "courts": [...] }`) para consulta pública. Com `?date=AAAA-MM-DD`, devolve só as quadras com algum horário livre no dia, no formato de `/api/availability`.                                                                                                                                                                                                                                 |
| `GET`    | `/api/courts/:id/slots?date=`         | Horários de 1 hora de uma quadra no dia (`200 { "date", "courtId", "courtName", "hourlyPriceCents", "slots" }`), com `status` `free`, `busy` ou `closed` (passado, bloqueado ou fechado). `404` se a quadra não existe.                                                                                                                                                                                                     |
| `GET`    | `/api/availability?date=`             | Horários de todas as quadras no dia (`200 { "date", "courts": [{ "courtId", "courtName", "hourlyPriceCents", "slots" }] }`), usado pelo app. Sem login e sem dados de quem reservou.                                                                                                                                                                                                                                        |
| `POST`   | `/api/bookings`                       | Cria a reserva de 1 hora com `{ "courtId", "startsAt", "customerName", "customerPhone" }` (`201 { "booking": {...} }`, com o `code`). Horário ocupado, passado, fechado, bloqueado ou além da janela de reserva: `409 SLOT_UNAVAILABLE`. Telefone que já tem 2 reservas confirmadas no dia do jogo (D01, comparado só pelos dígitos): `409 DAILY_LIMIT_REACHED`. Nome sem sobrenome ou telefone inválido: `422`. Sem login. |
| `POST`   | `/api/bookings/lookup`                | Consulta a reserva por `{ "code", "phone" }` (`200 { "booking" }`). Código ou telefone errados: `404` com a mesma mensagem genérica. 10 falhas em 15 minutos por IP ou por telefone: `429 TOO_MANY_ATTEMPTS`.                                                                                                                                                                                                               |
| `POST`   | `/api/bookings/cancel`                | Cancela pelo cliente com `{ "code", "phone" }` e libera o horário. Só até `CANCELLATION_DEADLINE_HOURS` horas antes (padrão 2, D02): depois disso `409 CHANGE_DEADLINE_PASSED`. Já cancelada: `409 BOOKING_ALREADY_CANCELLED`.                                                                                                                                                                                              |
| `POST`   | `/api/bookings/reschedule`            | Remarca com `{ "code", "phone", "courtId", "startsAt" }` mantendo o código. Mesmas regras da criação (horário livre, limite de 2 por dia na data de destino) e o mesmo prazo do cancelamento. Se falhar, a reserva antiga continua valendo (D10).                                                                                                                                                                           |
| `GET`    | `/api/owner/courts`                   | Lista todas as quadras do clube, incluindo as marcadas para remoção futura (`200 { "courts": [...] }`). Exige login.                                                                                                                                                                                                                                                                                                        |
| `POST`   | `/api/owner/courts`                   | Cadastra uma quadra com `{ "name", "hourlyPriceCents"?, "unavailableFrom"? }` (`201 { "court": {...} }`). Exige login.                                                                                                                                                                                                                                                                                                      |
| `PUT`    | `/api/owner/courts/:id`               | Atualiza os dados de uma quadra existente (`200 { "court": {...} }`). Exige login.                                                                                                                                                                                                                                                                                                                                          |
| `DELETE` | `/api/owner/courts/:id`               | Marca a quadra como indisponível a partir de `{ "unavailableFrom": "AAAA-MM-DD" }` (`200 { "court": {...} }`), ou bloqueia com `409 COURT_HAS_BOOKINGS` se houver reservas confirmadas a partir dessa data. Exige login.                                                                                                                                                                                                    |
| `GET`    | `/api/owner/courts/:id/schedule`      | Consulta a grade vigente (`validFrom` e `ranges`) e os bloqueios pontuais da quadra (`200`). Aceita `?date=AAAA-MM-DD`. Exige login.                                                                                                                                                                                                                                                                                        |
| `PUT`    | `/api/owner/courts/:id/schedule`      | Define ou atualiza as faixas semanais de 1 hora a partir de `validFrom`, rejeitando sobreposições (`409`) e sinalizando reservas existentes fora da nova faixa (`affectedBookings`). Exige login.                                                                                                                                                                                                                           |
| `GET`    | `/api/owner/courts/:id/opening-hours` | Alias compatível com o app para consultar `{ "openingHours" }`. Exige login.                                                                                                                                                                                                                                                                                                                                                |
| `POST`   | `/api/owner/courts/:id/opening-hours` | Alias compatível com o app para salvar `{ "validFrom", "ranges" }`. Exige login.                                                                                                                                                                                                                                                                                                                                            |
| `GET`    | `/api/owner/courts/:id/blocks`        | Lista bloqueios pontuais (ex.: manutenção) da quadra (`200 { "blocks": [...] }`). Exige login.                                                                                                                                                                                                                                                                                                                              |
| `POST`   | `/api/owner/courts/:id/blocks`        | Cria um bloqueio pontual `{ "startsAt", "endsAt", "reason"? }` sem apagar a regra semanal (`201`). Exige login.                                                                                                                                                                                                                                                                                                             |
| `DELETE` | `/api/owner/blocks/:id`               | Remove um bloqueio pontual (`204`). Exige login.                                                                                                                                                                                                                                                                                                                                                                            |
| `GET`    | `/api/owner/courts/:id/schedule`      | Consulta a grade vigente (`validFrom` e `ranges`) e os bloqueios pontuais da quadra (`200`). Aceita `?date=AAAA-MM-DD`. Exige login.                                                                                                                                                                                                                                                                                        |
| `PUT`    | `/api/owner/courts/:id/schedule`      | Define ou atualiza as faixas semanais de 1 hora a partir de `validFrom`, rejeitando sobreposições (`409`) e sinalizando reservas existentes fora da nova faixa (`affectedBookings`). Exige login.                                                                                                                                                                                                                           |
| `GET`    | `/api/owner/courts/:id/opening-hours` | Alias compatível com o app para consultar `{ "openingHours" }`. Exige login.                                                                                                                                                                                                                                                                                                                                                |
| `POST`   | `/api/owner/courts/:id/opening-hours` | Alias compatível com o app para salvar `{ "validFrom", "ranges" }`. Exige login.                                                                                                                                                                                                                                                                                                                                            |
| `GET`    | `/api/owner/courts/:id/blocks`        | Lista bloqueios pontuais (ex.: manutenção) da quadra (`200 { "blocks": [...] }`). Exige login.                                                                                                                                                                                                                                                                                                                              |
| `POST`   | `/api/owner/courts/:id/blocks`        | Cria um bloqueio pontual `{ "startsAt", "endsAt", "reason"? }` sem apagar a regra semanal (`201`). Exige login.                                                                                                                                                                                                                                                                                                             |
| `DELETE` | `/api/owner/blocks/:id`               | Remove um bloqueio pontual (`204`). Exige login.                                                                                                                                                                                                                                                                                                                                                                            |
| `GET`    | `/api/owner/courts/:id/schedule`      | Consulta a grade vigente (`validFrom` e `ranges`) e os bloqueios pontuais da quadra (`200`). Aceita `?date=AAAA-MM-DD`. Exige login.                                                                                                                                                                                                                                                                                        |
| `PUT`    | `/api/owner/courts/:id/schedule`      | Define ou atualiza as faixas semanais de 1 hora a partir de `validFrom`, rejeitando sobreposições (`409`) e sinalizando reservas existentes fora da nova faixa (`affectedBookings`). Exige login.                                                                                                                                                                                                                           |
| `GET`    | `/api/owner/courts/:id/opening-hours` | Alias compatível com o app para consultar `{ "openingHours" }`. Exige login.                                                                                                                                                                                                                                                                                                                                                |
| `POST`   | `/api/owner/courts/:id/opening-hours` | Alias compatível com o app para salvar `{ "validFrom", "ranges" }`. Exige login.                                                                                                                                                                                                                                                                                                                                            |
| `GET`    | `/api/owner/courts/:id/blocks`        | Lista bloqueios pontuais (ex.: manutenção) da quadra (`200 { "blocks": [...] }`). Exige login.                                                                                                                                                                                                                                                                                                                              |
| `POST`   | `/api/owner/courts/:id/blocks`        | Cria um bloqueio pontual `{ "startsAt", "endsAt", "reason"? }` sem apagar a regra semanal (`201`). Exige login.                                                                                                                                                                                                                                                                                                             |
| `DELETE` | `/api/owner/blocks/:id`               | Remove um bloqueio pontual (`204`). Exige login.                                                                                                                                                                                                                                                                                                                                                                            |
