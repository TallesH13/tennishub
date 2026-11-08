# Histórias de usuário e cenários de teste — TennisHub

Fonte: Documento de Visão, versão 6.0 (29/10/2026), seções 4.1 e 4.2. Requisitos: [requisitos.md](requisitos.md).

As histórias 01, 04, 05, 09, 10, 11 e 18 fazem parte do MVP. As histórias 02, 03, 06, 07, 08, 12 a 17 e 19 pertencem aos módulos complementares.

## Histórias de usuário

### História de Usuário 01: Login do Proprietário
**COMO UM** Proprietário
**EU QUERO** fazer login no sistema
**PARA** acessar a área de gestão das quadras e agendamentos com segurança

### História de Usuário 02: Pontos e Conquistas
**COMO UM** Cliente
**EU QUERO** acumular pontos e conquistas conforme jogo
**PARA** acompanhar minha evolução

### História de Usuário 03: Ranking Geral de Vitórias
**COMO UM** Cliente
**EU QUERO** visualizar um ranking atualizado com os jogadores de maior número de vitórias na temporada
**PARA** acompanhar minha evolução e comparar meu desempenho no clube

### História de Usuário 04: Consultar quadras disponíveis
**COMO UM** Cliente
**EU QUERO** visualizar a agenda de horários de quadras disponíveis sem fazer login
**PARA** decidir qual melhor quadra e horário disponível é compatível com minha agenda de forma rápida

### História de Usuário 05: Agendar uma quadra
**COMO UM** Cliente
**EU QUERO** marcar, desmarcar ou trocar horários
**PARA** reservar um horário na quadra e fazer gestão desse horário caso preciso alterá-lo

### História de Usuário 06: Registro do Pagamento no Local
**COMO UM** Proprietário
**EU QUERO** marcar o agendamento como pago quando o cliente pagar no local
**PARA** controlar quais reservas já foram pagas e quais estão pendentes

### História de Usuário 07: Consultar Instrutores Disponíveis
**COMO UM** Cliente
**EU QUERO** visualizar uma lista de instrutores disponíveis
**PARA** decidir qual instrutor pode me atender no horário que agendei a quadra

### História de Usuário 08: Contratação de Instrutor
**COMO UM** Cliente
**EU QUERO** contratar e agendar horário com um instrutor
**PARA** ter uma aula de tênis durante minha reserva

### História de Usuário 09: Consultar Reservas Confirmadas
**COMO UM** Proprietário
**EU QUERO** consultar os agendamentos realizados, filtrando por data, quadra e cliente
**PARA** organizar a operação do dia e conhecer o uso das quadras

### História de Usuário 10: Ajustar Agendamento de um Cliente
**COMO UM** Proprietário
**EU QUERO** realocar um horário de reserva de um cliente
**PARA** realizar alguma manutenção ou intervenção especial naquela quadra e horário

### História de Usuário 11: Emissão relatório de locações realizadas
**COMO UM** Proprietário
**EU QUERO** gerar relatórios das locações realizadas em um período, identificando clientes
**PARA** acompanhar uso e a receita do espaço

### História de Usuário 12: Instrutor visualiza agendamentos
**COMO UM** Instrutor
**EU QUERO** visualizar meus agendamentos
**PARA** organizar meu dia

### História de Usuário 13: Instrutor Aceita/Rejeita agendamento
**COMO UM** Instrutor
**EU QUERO** aceitar ou rejeitar solicitações de agendamento de aulas
**PARA** gerenciar minha programação

### História de Usuário 14: Consultar Itens disponíveis para aluguel e compra
**COMO UM** Cliente/Proprietário
**EU QUERO** visualizar itens disponíveis para aluguel e compra
**PARA** visualizar itens disponíveis na loja

### História de Usuário 15: Comprar um ou mais itens da loja
**COMO UM** Cliente
**EU QUERO** comprar um ou mais itens da loja
**PARA** ter em minha posse em definitivo um ou mais itens desejados

### História de Usuário 16: Alugar um ou mais itens da loja
**COMO UM** Cliente
**EU QUERO** alugar um ou mais itens da loja
**PARA** ter temporariamente em minha posse um ou mais itens desejados

### História de Usuário 17: Adicionar itens no estoque
**COMO UM** Proprietário
**EU QUERO** adicionar itens no estoque do almoxarifado
**PARA** gerenciar estoque mínimo de cada item e garantir disponibilidade deles para o cliente

### História de Usuário 18: Cadastro de Quadras
**COMO UM** Proprietário
**EU QUERO** cadastrar e editar quadras do meu clube
**PARA** manter atualizadas as quadras oferecidas aos clientes

### História de Usuário 19: Registro de Resultados das Partidas
**COMO UM** Instrutor
**EU QUERO** inserir e atualizar resultados e placares das partidas competitivas realizadas no clube no sistema
**PARA** manter ranking de competidores atualizado

## Cenários de teste

### História de Usuário 01
**Cenário 1 – Login Válido**
DADO que estou na tela de login de proprietários
QUANDO informo e-mail e senha corretos
ENTÃO o sistema me autentica e redireciona para o painel de gestão

**Cenário 2 – Credenciais Inválidas**
DADO que estou na tela de login
QUANDO informo e-mail ou senha incorretos
ENTÃO sistema recusa o acesso e exibe uma mensagem de erro, sem revelar qual campo está errado

**Cenário 3 – Sessão Expirada**
DADO que estou logado no painel de gestão
QUANDO minha sessão expira por inatividade
ENTÃO o sistema me desloga e solicita novo login ao tentar qualquer ação

### História de Usuário 02
**Cenário 1 – Pontuar ao Concluir Partida**
DADO que tenho um agendamento concluído no meu perfil
QUANDO o horário da minha reserva se encerra
ENTÃO o sistema credita pontos proporcionais ao tempo jogado

**Cenário 2 – Desbloquear Conquista**
DADO que atingi o número de partidas necessário para uma conquista
QUANDO concluo essa partida
ENTÃO o sistema desbloqueia o badge e me notifica

### História de Usuário 03
**Cenário 1 – Ordenação Padrão por Vitórias**
DADO que os atletas A (10 vitórias) e B (8 vitórias) possuem partidas registradas no sistema
QUANDO acesso a tela de "Ranking Geral"
ENTÃO o atleta A é exibido em uma posição superior à do atleta B

**Cenário 2 – Desempate por Saldo de Games**
DADO que os atletas X e Y possuem 5 vitórias cada, mas X tem saldo de +15 games e Y tem saldo de +10 games
QUANDO o ranking geral é gerado
ENTÃO o atleta X ocupa a posição à frente do atleta Y

### História de Usuário 04
**Cenário 1 – Consulta Quadras Disponíveis**
DADO acesso ao sistema
QUANDO selecionado opção de interface de cliente e dia do agendamento
ENTÃO é mostrado ao cliente as quadras disponíveis

**Cenário 2 – Consulta Horários Disponíveis**
DADO acesso ao sistema
QUANDO selecionado opção de interface de cliente, dia do agendamento e quadra disponível
ENTÃO é mostrado ao cliente os horários (com intervalo de 1 hora) que a quadra escolhida está disponível naquele dia

### História de Usuário 05
**Cenário 1 – Agendamento com Horário Disponível**
DADO que existem quadras disponíveis no horário selecionado
QUANDO escolho a quadra, a data e o horário, nome completo e telefone e confirmo o agendamento
ENTÃO o sistema registra a reserva e exibe ao jogador a confirmação com o código da reserva

**Cenário 2 – Horário Indisponível**
DADO que o horário selecionado já está reservado por outro jogador
QUANDO tento realizar o agendamento
ENTÃO o sistema informa que o horário está indisponível e não permite a reserva

**Cenário 3 – Limite de Reservas Atingido**
DADO que existem quadras disponíveis no horário selecionado
QUANDO tento realizar o agendamento e já agendei 2 horários nesse mesmo dia
ENTÃO o sistema informa que limite de agendamentos diários foi ultrapassado e sugere que o cliente altere a data de agendamento

**Cenário 4 – Cancelamento de Agendamento**
DADO que possuo um agendamento futuro e informo o telefone e o código da reserva
QUANDO solicito o cancelamento dentro do prazo permitido
ENTÃO o sistema cancela a reserva e disponibiliza o horário novamente

### História de Usuário 06
**Cenário 1 – Registrar Pagamento**
DADO que o cliente pagou o horário no local, em dinheiro ou cartão
QUANDO marco o agendamento como pago e informo a forma de pagamento
ENTÃO o sistema registra o pagamento com a data e a forma usada e mostra o agendamento como pago

**Cenário 2 – Pagamento Pendente**
DADO que o horário do agendamento já passou e o pagamento não foi registrado
QUANDO consulto os agendamentos
ENTÃO o sistema mostra o agendamento como pendente de pagamento

### História de Usuário 07
**Cenário 1 – Lista Instrutores Disponíveis**
DADO que o cliente acessa o sistema
QUANDO ele clica na aba de instrutores
ENTÃO o sistema lista os instrutores que atendem naquele clube de tênis

### História de Usuário 08
**Cenário 1 – Instrutor Disponível**
DADO que estou na tela de instrutores disponíveis
QUANDO seleciono um instrutor para o meu horário agendado e confirmo
ENTÃO o sistema registra a solicitação e notifica o instrutor

**Cenário 2 – Instrutor Indisponível**
DADO que quero contratar um instrutor para o meu horário
QUANDO nenhum instrutor está disponível naquele horário
ENTÃO o sistema informa e sugere outros horários com instrutor livre

### História de Usuário 09
**Cenário 1 – Listar Agendamentos Realizados**
DADO que o proprietário está autenticado no sistema
QUANDO ele clica na aba de consultas e seleciona um período/data, quadra e ou cliente
ENTÃO o sistema retorna a lista de agendamentos realizados que atendem aos filtros ativos naquela pesquisa

### História de Usuário 10
**Cenário 1 – Ajuste Horário de um Agendamento**
DADO que o proprietário está autenticado no sistema
QUANDO ele executar uma consulta a um agendamento específico, selecionar a opção editar, e ajustar data do agendamento ou cancelar o agendamento e salvar
ENTÃO o sistema deve processar essa alteração que o proprietário solicitou e enviar uma notificação ao cliente, referente a essa alteração/cancelamento

### História de Usuário 11
**Cenário 1 – Emissão de Relatório**
DADO que o proprietário está autenticado no sistema
QUANDO ele seleciona a opção de relatórios, indicando período e ou cliente
ENTÃO o sistema emite um relatório em PDF com os dados financeiros desses agendamentos filtrados

### História de Usuário 12
**Cenário 1 – Lista Agendamentos de Aulas do Instrutor Confirmados**
DADO que o instrutor está autenticado no sistema
QUANDO abre sua agenda e seleciona a data que deseja consultar sua programação
ENTÃO o sistema mostra a lista de agendamentos de aulas já aceitos pelo instrutor naquela data selecionada

### História de Usuário 13
**Cenário 1 – Lista Solicitações de Agendamentos de Aulas do Instrutor**
DADO que o cliente realizou uma solicitação de aula com o instrutor e esse instrutor está autenticado no sistema
QUANDO o instrutor abrir a aba de solicitações de agendamento de aula pendentes, ele poderá aceitar/rejeitar essa solicitação de agendamento
ENTÃO o sistema irá processar essa resposta que o instrutor der, de acordo com opção selecionada, e irá notificar o cliente e atualizar a agenda do instrutor se necessário

### História de Usuário 14
**Cenário 1 – Visualizar Lista de Itens na Loja**
DADO que o cliente/proprietário acesse o sistema
QUANDO acessarem a tela da loja
ENTÃO o sistema irá mostrar o catálogo de itens para aluguel e venda e quantidade disponível daquele produto

### História de Usuário 15
**Cenário 1 – Comprar Item**
DADO que o usuário acessa o sistema
QUANDO o usuário selecionar um ou mais itens, definindo quantidade de cada item, e selecionar opção de compra e confirmar o pedido
ENTÃO o sistema registra o pedido com pagamento no local e, depois que o proprietário confirma o pagamento feito no clube, notifica o usuário que a compra foi confirmada e emite um recibo da compra, notifica o proprietário para que ele possa separar e entregar os itens comprados no clube ao cliente e o sistema também dá baixa no estoque/catálogo da loja dos itens comprados de acordo com a quantidade adquirida de cada um

### História de Usuário 16
**Cenário 1 – Alugar Item**
DADO que o usuário acessa o sistema
QUANDO o usuário selecionar um ou mais itens, definindo quantidade de cada item, e selecionar opção de aluguel, prazo do aluguel desejado e confirmar o pedido
ENTÃO o sistema registra o pedido com pagamento no local e, depois que o proprietário confirma o pagamento feito no clube, notifica o usuário que o aluguel foi confirmado e emite um recibo da locação, notifica o proprietário para que ele possa separar e entregar os itens alugados no clube ao cliente e o sistema também altera o status dos itens envolvidos na transação para "Alugados" e define lembrete de notificação ao cliente e proprietário quando esse prazo vencer. Além disso esse item deve deixar de aparecer como disponível no catálogo da loja

### História de Usuário 17
**Cenário 1 – Adicionar Item no Estoque**
DADO que o proprietário está autenticado no sistema e acessando a tela do catálogo da loja
QUANDO ele clicar no botão de adicionar itens, ele vai selecionar o item a ser adicionado e a quantidade a ser adicionada e salvar
ENTÃO o sistema deverá processar essa operação e somar a quantidade adicionada daquele item à quantidade já disponível dele e realizar a atualização do catálogo da loja para mostrar a nova quantidade disponível daquele item

**Cenário 2 – Registrar Devolução de Item Alugado**
DADO que o proprietário está autenticado no sistema, e um item X possui o status como "Alugado"
QUANDO o cliente realizar a devolução do item no prazo determinado, o proprietário deverá alterar o estado do item para "Disponível"
ENTÃO o sistema deverá processar o comando e atualizar o status do item, notificar o cliente que o item foi devolvido e voltar a mostrar esse item no catálogo da loja

### História de Usuário 18
**Cenário 1 – Cadastro de Nova Quadra**
DADO que o proprietário acessa o painel de gestão
QUANDO seleciona opção de cadastrar quadra, informando nome da quadra e horários que será possível realizar agendamento na quadra e data que a quadra vai estar disponível para reservas
ENTÃO o sistema registra esses dados da nova quadra e já torna ela disponível na aba dos clientes para novas reservas na data informada

**Cenário 2 – Edição de Quadra**
DADO que o proprietário acessa o painel de gestão
QUANDO seleciona opção de editar quadra, informando nome da quadra e editando horários disponíveis para reservas na quadra e a partir de que data esses novos horários passam a valer
ENTÃO o sistema registra esses novos dados da quadra e já ajusta os horários disponíveis na aba dos clientes para novas reservas na data informada

**Cenário 3 – Remoção de Quadra**
DADO que o proprietário acessa o painel de gestão
QUANDO seleciona opção de remover quadra, informando nome da quadra e data que a quadra vai deixar de estar disponível para reservas
ENTÃO o sistema registra esse comando e programa a remoção da quadra da lista de disponíveis a partir da data informada

### História de Usuário 19
**Cenário 1 – Adicionar Resultado e Pontuação**
DADO que o instrutor acessa o painel de pontuações
QUANDO seleciona opção de adicionar resultado e inserir resultado e pontuações e salva
ENTÃO o sistema registra esse comando, registra o resultado e pontuações, atualizando o ranking de competidores

**Cenário 2 – Editar Resultado e Pontuação**
DADO que o instrutor acessa o painel de pontuações
QUANDO seleciona opção de editar resultado para alterar resultados e pontuações e salva
ENTÃO o sistema registra esse comando, altera os dados alterados no jogo selecionado e atualiza o ranking de competidores

**Cenário 3 – Remover Resultado e Pontuação**
DADO que o instrutor acessa o painel de pontuações
QUANDO seleciona opção de remover resultado e seleciona confirmar
ENTÃO o sistema registra esse comando e remove o registro daquele resultado e pontuação do sistema e atualiza o ranking de competidores
