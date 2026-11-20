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

Os testes de integração usam um PostgreSQL real. Por segurança, **só rodam em bancos cujo nome termina em `_test`**, porque apagam e recriam o schema a cada execução.

```bash
createdb tennishub_test
echo "DATABASE_URL=postgres://postgres:postgres@localhost:5432/tennishub_test" > .env.test
```

No CI, o banco `tennishub_test` sobe como serviço do próprio job.

## Scripts

| Comando                | O que faz                                                                               |
| ---------------------- | --------------------------------------------------------------------------------------- |
| `npm run dev`          | Sobe a API em modo de desenvolvimento, recarregando a cada alteração.                   |
| `npm run build`        | Compila o TypeScript para `dist/`.                                                      |
| `npm start`            | Roda a versão compilada (`dist/server.js`).                                             |
| `npm run lint`         | ESLint + verificação de formatação do Prettier.                                         |
| `npm run format`       | Formata o código com o Prettier.                                                        |
| `npm run typecheck`    | Checa os tipos sem gerar arquivos.                                                      |
| `npm test`             | Recria o banco de teste, aplica as migrations e roda os testes de unidade e integração. |
| `npm run migrate`      | Aplica as migrations pendentes (usa `DATABASE_URL_DIRECT`).                             |
| `npm run migrate:down` | Desfaz a última migration.                                                              |
| `npm run seed`         | Cria/atualiza o proprietário a partir do `.env` e insere dados de exemplo.              |

Antes de abrir um PR: `npm run lint && npm run typecheck && npm test`.

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

| Método | Rota          | Descrição                                                                                                           |
| ------ | ------------- | ------------------------------------------------------------------------------------------------------------------- |
| `GET`  | `/api/health` | `200 { "status": "ok", "database": "ok" }` quando a API e o banco respondem; `503` se o banco estiver indisponível. |
