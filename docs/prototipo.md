# Protótipo de telas

Protótipo de alta fidelidade do TennisHub (issue #9). Serve de referência para as telas do app (issues #22 a #29).

| Item | Onde |
|---|---|
| Arquivo no Figma (leitura) | https://www.figma.com/design/5FprJpDc4bO7rZsPjgeUlg/TennisHub-%E2%80%93-Prot%C3%B3tipo?node-id=0-1&t=h63TLAEaMM092YXm-1 |
| Exportações em PNG | [`docs/prototipo/`](prototipo/) |
| Tema implementado no app | `app/lib/core/theme/` |

Todas as telas são para desktop (1440 × 1024), foco do MVP (RNF06).

## Fluxo do cliente (RNF08)

O cliente reserva uma quadra em 4 passos, sem criar conta:

| Passo | Tela | Ação |
|---|---|---|
| 1 | Consulta de horários | Escolhe o dia e clica em um horário livre |
| 2 | Seus dados | Informa nome e telefone |
| 3 | Seus dados | Clica em "Confirmar reserva" |
| 4 | Reserva confirmada | Recebe o código da reserva |

## Telas

### Área do cliente

| Tela | Estados | PNG | Issue |
|---|---|---|---|
| Consulta de horários | padrão, carregando, vazio, erro | `cli-horarios*.png` | #22 |
| Agendamento (seus dados) | preenchendo, erro de validação, limite de 2 por dia, horário reservado por outra pessoa, confirmando | `cli-dados*.png` | #23 |
| Reserva confirmada | sucesso | `cli-confirmada.png` | #23 |
| Minha reserva | busca, não encontrada, detalhes, cancelar, remarcar | `cli-reserva*.png` | #24 |

### Painel do proprietário

| Tela | Estados | PNG | Issue |
|---|---|---|---|
| Login | padrão, erro, carregando | `prop-login*.png` | #25 |
| Quadras | lista, editar, vazio | `prop-quadras*.png` | #26 |
| Horários e bloqueios | funcionamento, nova vigência com reservas afetadas | `prop-horarios*.png` | #26 |
| Agendamentos | lista com filtros, carregando, vazio | `prop-agendamentos*.png` | #27 |
| Realocar e cancelar | diálogos com motivo obrigatório | `prop-agendamentos-realocar.png`, `prop-agendamentos-cancelar.png` | #28 |
| Relatório de locações | com dados, vazio | `prop-relatorio*.png` | #29 |

## Tema

Material 3 com cor-base `#1F6F43`. Os valores abaixo são os mesmos do tema do app.

### Cores

| Uso | Cor | No código |
|---|---|---|
| Primária | `#2D6A45` | `colorScheme.primary` |
| Container primário | `#B0F1C2` | `colorScheme.primaryContainer` |
| Container secundário | `#D2E8D4` | `colorScheme.secondaryContainer` |
| Cor-base do tema | `#1F6F43` | `AppColors.courtGreen` |
| Destaque | `#D7E84A` | `AppColors.ballYellow` |
| Fundo das páginas | `#F7F8F6` | `AppColors.background` |
| Superfície (cards) | `#F6FBF3` | `colorScheme.surface` |
| Texto | `#181D19` | `colorScheme.onSurface` |
| Texto secundário | `#414942` | `colorScheme.onSurfaceVariant` |
| Contorno | `#717971` | `colorScheme.outline` |
| Contorno suave | `#C0C9BF` | `colorScheme.outlineVariant` |
| Erro | `#BA1A1A` | `colorScheme.error` |
| Container de erro | `#FFDAD6` | `colorScheme.errorContainer` |
| Aviso | `#FFDF9E` | a incluir no tema |
| Horário livre | `#DDF2E3` | `AppColors.slotAvailable` |
| Horário ocupado | `#E6E6E6` | `AppColors.slotUnavailable` |

### Tipografia

Fonte Roboto, escala do Material 3.

| Uso | Tamanho / altura | Peso | No código |
|---|---|---|---|
| Título da página | 28 / 36 | Regular | `headlineMedium` |
| Título de seção e diálogo | 22 / 28 | Regular | `titleLarge` |
| Subtítulo | 16 / 24 | Medium | `titleMedium` |
| Corpo grande | 16 / 24 | Regular | `bodyLarge` |
| Corpo | 14 / 20 | Regular | `bodyMedium` |
| Rótulo (botões, menus) | 14 / 20 | Medium | `labelLarge` |
| Legenda | 12 / 16 | Regular | `bodySmall` |

### Espaçamento e arredondamento

| Item | Valor |
|---|---|
| Espaçamentos | 4, 8, 16, 24, 32 e 48 (`AppSpacing`) |
| Arredondamento | 6 em selos e horários, 8 em cards, campos e botões (`AppRadius.md`), 16 em diálogos |
| Altura dos botões | 48 |
| Largura máxima do conteúdo | 1200 (`AppBreakpoints.maxContentWidth`) |

## Componentes base

| Componente | Variações |
|---|---|
| Botão | principal, secundário, contorno, texto, destrutivo, desabilitado, carregando |
| Campo | vazio, com foco, preenchido, erro, seleção, data |
| Grade de horários | livre, ocupado, selecionado, fechado, reserva atual |
| Selo de situação | confirmada, cancelada, realocar, ativa, indisponível |
| Aviso | erro, informação, atenção, snackbar |
| Diálogo | confirmação, formulário |
| Tabela | listas do painel |

## Estados

Toda tela que busca dados mostra quatro estados:

| Estado | Como aparece |
|---|---|
| Carregando | Blocos cinza no lugar do conteúdo; botões com indicador de progresso |
| Vazio | Ícone, título, explicação e uma ação para sair do estado |
| Erro | Mensagem que diz o que fazer e botão "Tentar novamente"; erros de campo abaixo do campo |
| Sucesso | Confirmação na tela (reserva) ou snackbar (ações rápidas) |
