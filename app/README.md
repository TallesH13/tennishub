# TennisHub — App (Flutter Web)

Interface web do TennisHub: área pública do cliente e painel do proprietário.

## Pré-requisitos

- Flutter (canal stable) com suporte a web
- Google Chrome

Confira com `flutter doctor`: para este projeto bastam os itens **Flutter** e **Chrome**.

## Como rodar

```bash
cd app
flutter pub get
flutter run -d chrome
```

Por padrão, o app usa **dados falsos em memória** e roda sem a API. Para usar a API real, informe o modo e o endereço na compilação:

```bash
flutter run -d chrome --dart-define=API_MODE=http --dart-define=API_BASE_URL=http://localhost:8080
```

| Definição | Valores | Padrão |
|---|---|---|
| `API_MODE` | `fake` (dados falsos) ou `http` (API real) | `fake` |
| `API_BASE_URL` | Endereço da API, sem `/api` no final | Mesmo endereço em que o app foi aberto (caso da apresentação, em que a API serve o build do Flutter) |

No modo `fake`, o login do proprietário é `proprietario@tennishub.com` / `tennishub123`.

Com o app e a API em portas diferentes, a API precisa liberar CORS para o endereço do app.

Se o Chrome não abrir sozinho, use `flutter run -d web-server --web-port 8080` e acesse o endereço exibido no terminal.

## Testes e verificações

Rode antes de abrir um Pull Request (são os mesmos passos do CI):

```bash
dart format .
flutter analyze
flutter test
```

## Rotas

| Rota | Tela | Acesso |
|---|---|---|
| `/` | Área pública (consulta e agendamento) | Livre |
| `/admin` | Painel do proprietário | Login (a partir da issue #25) |
| `/admin/relatorios` | Relatório de locações | Login (a partir da issue #25) |

O app usa URLs com `#` (ex.: `http://localhost:8080/#/admin`), que funcionam em qualquer servidor sem configuração extra.

## Estrutura

```
lib/
  main.dart                ponto de entrada
  app.dart                 tema e rotas
  core/
    config/                configurações por --dart-define
    formatting/            datas, valores e telefones no padrão brasileiro
    fake/                  simulação da API em memória (modo fake)
    layout/                layout base das páginas (AppPage)
    network/               cliente HTTP, erros da API e leitura de JSON
    router/                rotas (AppRoutes) e roteador (go_router)
    session/               sessão do proprietário
    theme/                 cores, espaçamentos e tema
    time/                  relógio injetável (nos testes, fixa o "hoje")
    widgets/               componentes compartilhados
  features/
    <funcionalidade>/
      data/                acesso à API e implementações falsas (repositórios)
      domain/              modelos e interfaces dos repositórios
      presentation/        páginas, widgets e estado (Riverpod)
test/                      espelha a estrutura de lib/
```

Funcionalidades previstas:

| Pasta | Conteúdo | Requisitos |
|---|---|---|
| `courts` | Consulta pública de quadras e horários; gestão de quadras e horários | RF01, RF06, RF07 |
| `bookings` | Agendamento, cancelamento e remarcação; consulta e realocação pelo proprietário | RF02 a RF04, RF08, RF09 |
| `auth` | Login do proprietário e sessão | RF05 |
| `reports` | Relatório de locações: filtros, totais, tabela e exportação em PDF | RF10 |
| `admin` | Estrutura do painel do proprietário | — |

## Convenções

- Identificadores (classes, variáveis, arquivos) em inglês; textos de tela, comentários e documentação em português.
- Material importado de `package:material_ui/material_ui.dart` (o `package:flutter/material.dart` está depreciado).
- Imports sempre no formato `package:tennishub/...`.
- Cores, espaçamentos e estilos vêm de `core/theme`; evite valores soltos nas telas.
- Rotas sempre pelas constantes de `AppRoutes`.
- Estado com Riverpod; as telas recebem os dados pelos providers, o que permite trocar a API por implementações falsas nos testes.

## Camada de dados (issue #21)

Cada funcionalidade tem uma interface de repositório em `domain/` e duas implementações em `data/`: HTTP (API real) e falsa (memória). O provider escolhe uma pelo `API_MODE`; as telas só conhecem a interface.

| Funcionalidade | Provider | Interface |
|---|---|---|
| Autenticação | `authRepositoryProvider` | `AuthRepository` |
| Quadras e horários livres | `courtsRepositoryProvider` | `CourtsRepository` |
| Funcionamento e bloqueios | `courtScheduleRepositoryProvider` | `CourtScheduleRepository` |
| Reservas do cliente | `bookingsRepositoryProvider` | `BookingsRepository` |
| Agendamentos do painel | `ownerBookingsRepositoryProvider` | `OwnerBookingsRepository` |
| Relatório | `reportsRepositoryProvider` | `ReportsRepository` |

O formato de cada endpoint está em [`docs/api.md`](../docs/api.md).

**Erros.** Toda falha vira uma `ApiException` (`core/network/api_exception.dart`) com `message` pronta para a tela:

| Exceção | Quando | O que a tela faz |
|---|---|---|
| `SlotUnavailableException` | Horário reservado por outra pessoa | Avisa e volta para a grade |
| `DailyLimitException` | Telefone já tem 2 reservas no dia | Mostra a mensagem no formulário |
| `ValidationException` | Dados inválidos | Mostra `fieldErrors[campo]` abaixo de cada campo |
| `NotFoundException` | Código e telefone sem reserva | Mostra a mensagem |
| `InvalidCredentialsException` | E-mail ou senha errados | Mostra a mensagem no login |
| `UnauthorizedException` | Sessão expirada | A sessão já foi limpa; vai para o login |
| `NetworkException` | Sem conexão ou tempo esgotado | Botão "Tentar novamente" |

**Sessão.** `authControllerProvider` entra (`signIn`), sai (`signOut`) e recupera a sessão ao abrir o app (`restoreSession`). A sessão fica em `sessionStoreProvider`: a credencial vai no cabeçalho de toda chamada e nunca aparece em log nem em mensagem de erro. Qualquer 401 limpa a sessão; as rotas do painel (issue #25) observam `sessionStoreProvider` para mandar ao login.

## Relatório de locações (issue #29)

A tela `/admin/relatorios` (`features/reports`) permite ao proprietário:

- escolher o período (datas `dd/mm/aaaa`, com os atalhos "Este mês" e "Mês passado") e, se quiser, filtrar por cliente (nome ou telefone) e quadra;
- ver as locações realizadas, com o cliente identificado, e os totais gerais e por quadra (locações, horas e valor);
- baixar o mesmo relatório em PDF.

Enquanto a API não está integrada (issues #20 e #21), os dados vêm de `FakeReportsRepository`, que gera locações de exemplo dos últimos 60 dias e um PDF simples. A troca pela implementação HTTP é feita em `features/reports/data/reports_providers.dart`, sem mexer nas telas. O download do PDF usa `package:web` e só funciona no navegador.
