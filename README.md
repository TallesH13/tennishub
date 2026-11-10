# TennisHub — Agendamento de Quadras de Tênis

Sistema web (Flutter) para agendamento de quadras de tênis. Projeto da disciplina **CSI405 – Gerência de Projetos de Software** (UFOP / ICEA / DECSI, 2026/2).

- **Clientes**: consultam quadras e horários e agendam 1 hora (máx. 2 por dia) informando nome e telefone — **sem login**.
- **Proprietário**: faz login e gerencia quadras, horários, agendamentos e relatórios de locações.

## Equipe

Lucas Lucio Silva Caixeta · Mateus Serretti Mendes Peixoto · Samuel Patrick Lopes de Oliveira · Talles Henrique Furtunato Lima (gerente de projeto) · Tulio Vilela Lopes

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
- Banco de dados: PostgreSQL
- Execução: 100% local, sem hospedagem

## Integração contínua

Todo Pull Request para a `main` executa o pipeline do GitHub Actions (`.github/workflows/ci.yml`): formatação, análise estática, testes e build do app Flutter, e lint, build e testes da API. A branch `main` só recebe merge com o check **CI OK** aprovado.

## Pré-requisitos

- Flutter (canal stable) e Google Chrome
- Node.js 24 (LTS) e npm
- PostgreSQL 16

## Como rodar

> Será preenchido conforme o app e a API forem sendo criados.

## Licença

[MIT](LICENSE)
