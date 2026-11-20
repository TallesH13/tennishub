# TennisHub — Agendamento de Quadras de Tênis

Sistema web (Flutter) para agendamento de quadras de tênis. Projeto da disciplina **CSI405 – Gerência de Projetos de Software** (UFOP / ICEA / DECSI, 2026/2).

- **Clientes**: consultam quadras e horários e agendam 1 hora (máx. 2 por dia) informando nome e telefone — **sem login**.
- **Proprietário**: faz login e gerencia quadras, horários, agendamentos e relatórios de locações.

## Equipe

Lucas Lucio Silva Caixeta · Mateus Serretti Mendes Peixoto · Samuel Patrick Lopes de Oliveira · Talles Henrique Furtunato Lima · Tulio Vilela Lopes

## Documentação

- [Requisitos](docs/requisitos.md) — requisitos funcionais e não funcionais, premissas e restrições
- [Histórias de usuário e cenários de teste](docs/historias-de-usuario.md)

## Estrutura

```
app/    Flutter Web (cliente e painel do proprietário)
api/    Backend REST em Node.js + TypeScript, com migrations (PostgreSQL)
docs/   Requisitos e histórias de usuário
```

## Tecnologias

- Frontend: Flutter (Web)
- Backend: Node.js + TypeScript (API REST)
- Banco de dados: PostgreSQL no Neon Serverless
- Execução: aplicação e API locais, sem hospedagem

## Integração contínua

Todo Pull Request para a `main` executa o pipeline do GitHub Actions (`.github/workflows/ci.yml`): formatação, análise estática, testes e build do app Flutter, e lint, build e testes da API. A branch `main` só recebe merge com o check **CI OK** aprovado.

## Qualidade e segurança

Uma rotina única confere qualidade e segurança. Ela roda no seu computador e no GitHub Actions (workflow "Qualidade e segurança") com os mesmos comandos:

```bash
.github/scripts/quality.sh                    # tudo
.github/scripts/quality.sh app --with-build   # app, incluindo o build web
.github/scripts/quality.sh api --install      # API (instala as dependências antes)
.github/scripts/quality.sh --help             # todas as opções
```

| Verificação | O que confere |
|---|---|
| Segredos | Chaves privadas, tokens, senhas escritas no código, endereços de banco com senha (como os do Neon) e arquivos `.env` versionados. Também examina o resultado do build web. |
| Políticas do código | Sem endereço fixo no app, sem `print` com dados pessoais, SQL só com parâmetros, sem `Math.random` para códigos, CORS restrito, TLS do banco ligado e sem segredo nos logs (RNF05, RNF07). |
| Cobertura de testes | Mínimo de 85% das linhas e de 90% da lógica de negócio (domínio, dados, estado e formatação). Arquivos que nenhum teste carrega contam como 0%. Ajuste com `COVERAGE_MIN_TOTAL` e `COVERAGE_MIN_LOGIC`. |
| Análise e testes | Formatação, `flutter analyze` com lints de segurança, testes do app e, na API, tipos, lint e testes de unidade. |
| Dependências | Na API, `npm audit`: bloqueia vulnerabilidade alta ou crítica em produção e avisa sobre as críticas em ferramentas de desenvolvimento. No app, lista as dependências diretas desatualizadas. O Dependabot abre Pull Requests de atualização toda semana. |

Cada passo termina em `ok`, `AVISO` (não bloqueia) ou `FALHA`. Para ignorar uma linha de propósito, escreva `secret-scan:ignore` (segredos) ou `policy-ignore: motivo` (políticas) nela. Os próprios scripts têm testes: `.github/scripts/tests/run-tests.sh`.

Se um segredo de verdade for versionado, troque-o no serviço de origem (por exemplo, redefina a senha do banco no Neon) antes de apagá-lo do código: ele continua no histórico do Git.

## Pré-requisitos

- Flutter (canal stable) e Google Chrome
- Node.js 24 (LTS) e npm
- Conta gratuita no Neon (banco de dados)
- PostgreSQL 16 local (testes automatizados e plano B)

## Como rodar

> Será preenchido conforme o app e a API forem sendo criados.

## Licença

[MIT](LICENSE)
