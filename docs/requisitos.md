# Requisitos — TennisHub

Fonte: Documento de Visão, versão 6.0 (29/10/2026). Histórias de usuário e cenários de teste: [historias-de-usuario.md](historias-de-usuario.md).

Os requisitos RF01 a RF10 formam o escopo desta versão (MVP): RF01 a RF03, RF05 a RF08 e RF10 vêm do enunciado do trabalho; RF04 e RF09 foram definidos pelo grupo. Os requisitos RF11 a RF17 são dos módulos complementares (premissa "Funcionalidades Definidas pelo Grupo"). Entre parênteses estão as histórias de usuário que detalham cada requisito.

## Requisitos funcionais — parte não gamificada (MVP)

- **RF01 – Consulta de Quadras e Horários Disponíveis:** O sistema deve permitir ao cliente, sem login, consultar em tempo real as quadras e os horários disponíveis. (HU04)
- **RF02 – Agendamento de Horário:** O sistema deve permitir ao cliente agendar um horário de 1 hora em uma quadra, informando nome completo e telefone, sem criar conta. (HU05)
- **RF03 – Limite Diário de Agendamentos:** O sistema deve impedir que o mesmo cliente, identificado pelo telefone, tenha mais de 2 agendamentos no mesmo dia. (HU05)
- **RF04 – Cancelamento e Remarcação pelo Cliente:** O sistema deve permitir ao cliente cancelar ou trocar um agendamento informando o telefone e o código da reserva. (HU05)
- **RF05 – Login do Proprietário:** O sistema deve exigir login com e-mail e senha para acesso à área do proprietário. (HU01)
- **RF06 – Cadastro e Gestão de Quadras:** O sistema deve permitir ao proprietário cadastrar, editar e remover quadras. (HU18)
- **RF07 – Disponibilização de Horários:** O sistema deve permitir ao proprietário definir os dias e horários em que cada quadra fica disponível para agendamento. (HU18)
- **RF08 – Consulta de Agendamentos:** O sistema deve permitir ao proprietário consultar os agendamentos realizados, filtrando por data, quadra e cliente. (HU09)
- **RF09 – Realocação de Horários pelo Proprietário:** O sistema deve permitir ao proprietário alterar o horário de um agendamento, registrando o motivo para que o cliente seja avisado. (HU10)
- **RF10 – Relatório de Locações:** O sistema deve gerar relatórios das locações realizadas em um período informado, identificando os respectivos clientes. (HU11)

## Requisitos funcionais — parte não gamificada (módulos complementares)

- **RF11 – Catálogo e Agendamento com Instrutores:** O sistema deve exibir a lista de instrutores disponíveis, permitir o canal de contato direto e possibilitar a contratação/agendamento de horários de aula, com agenda própria do instrutor. (HU07, HU08, HU12, HU13)
- **RF12 – Controle de Pagamento no Local:** O sistema deve permitir ao proprietário marcar o agendamento como pago no local, registrando a forma de pagamento (dinheiro ou cartão), para controlar as reservas pendentes. (HU06)
- **RF13 – Aluguel e Venda de Equipamentos:** O sistema deve permitir que o cliente selecione e adicione ao pedido o aluguel ou a compra de equipamentos (raquetes, bolinhas de tênis, etc.) integrados ao agendamento, com pagamento feito no local, na retirada. (HU14, HU15, HU16)
- **RF14 – Gestão de Almoxarifado e Estoque:** O sistema deve permitir ao proprietário controlar o estoque de itens e equipamentos (entradas, saídas, controle de saldo e disponibilidade para locação/venda). (HU17)

## Requisitos funcionais — parte gamificada (módulos complementares)

- **RF15 – Gestão de Ranking Geral:** O sistema deve calcular e exibir o ranking de atletas ordenado por número de vitórias, aplicando o saldo de games como critério de desempate. (HU03, HU19)
- **RF16 – Ranking de Média de Pontos:** O sistema deve calcular a média de pontos/games por partida e restringir a exibição no ranking apenas aos atletas que cumprirem a cota mínima de jogos. (HU02, HU03)
- **RF17 – Concessão de Badges e Notificações:** O sistema deve conceder insígnias de conquista automaticamente ao atingir os marcos do jogo e disparar notificações visuais (modais) de celebração. (HU02)

## Requisitos não funcionais — parte não gamificada (MVP)

- **RNF01 – Controle de Concorrência (Double Booking):** O sistema deve impedir que duas pessoas consigam agendar o mesmo horário, quadra ou instrutor, mesmo quando os pedidos forem feitos ao mesmo tempo.
- **RNF02 – Notificações:** Nesta versão, as confirmações são exibidas na tela e os avisos de realocação são feitos pelo telefone cadastrado. Nos módulos complementares, o sistema deve contar com serviço de notificações (Push, e-mail ou WhatsApp/SMS) para envio instantâneo das solicitações de realocação de horários e confirmações de pedidos.
- **RNF03 – Tempo de Resposta da Grade:** A consulta de horários disponíveis e atualização do estado das quadras deve responder em menos de 1,5 segundo para evitar desistências no fluxo de reserva.
- **RNF04 – Manutenibilidade do Código:** O código do sistema deve ser organizado e documentado de forma a facilitar futuras correções, alterações e inclusão de novas funcionalidades.
- **RNF05 – Segurança:** As senhas do proprietário devem ser armazenadas de forma criptografada, a comunicação deve usar HTTPS e chaves de acesso não podem ficar no repositório de código.
- **RNF06 – Compatibilidade:** A aplicação deve funcionar nas versões atuais dos navegadores Google Chrome, Mozilla Firefox e Microsoft Edge em computadores (Desktop/PC).
- **RNF07 – Privacidade (LGPD):** Os dados pessoais dos clientes (nome e telefone) devem ser usados apenas para o agendamento e ficar visíveis somente para o proprietário.
- **RNF08 – Usabilidade:** Um cliente sem treinamento deve conseguir concluir um agendamento em até 2 minutos.

## Requisitos não funcionais — parte gamificada (módulos complementares)

- **RNF09 – Desempenho:** A consulta aos rankings e o cálculo de pontuação devem ter tempo de resposta inferior a 2 segundos, mesmo em horários de pico.
- **RNF10 – Segurança e Concorrência:** As transações de débito de pontos na loja de recompensas devem ser atômicas, garantindo que não ocorram resgates duplicados ou saldo negativo por requisições simultâneas.

## Perspectiva do produto

É um produto implantado em ambiente Web. Ele centraliza as operações do estabelecimento esportivo sem depender de sistemas externos, integrando a interface do cliente e o painel do proprietário em uma única plataforma online, preparada para receber os módulos complementares (como a gamificação).

- **Interfaces de usuário:** aplicação Web responsiva desenvolvida em Flutter, acessível por navegadores.
- **Interfaces de hardware:** computadores com acesso à internet.
- **Interface de software:** comunicação da aplicação em Flutter com o backend via API REST/Websockets, integrados ao banco de dados relacional em nuvem Neon Serverless (PostgreSQL) para persistência e sincronização de dados de agendamentos, estoque e ranking em tempo real.

## Premissas

- **Conectividade:** clientes e proprietários dispõem de acesso contínuo à internet para consulta de horários e atualizações na agenda.
- **Adoção Operacional:** o proprietário alimentará o banco de dados com as informações de horários disponíveis, itens do almoxarifado e catálogo da loja.
- **Suporte do Framework:** o framework Flutter Web manterá compatibilidade estável com os principais navegadores do mercado durante todo o ciclo de vida do projeto.
- **Disponibilidade da Equipe:** os integrantes do projeto terão disponibilidade para cumprir as entregas dentro do cronograma acadêmico da disciplina, dedicando em média 2 horas por dia útil ao projeto (base do cronograma e da planilha de custos).
- **Uso em Computador:** o sistema será utilizado principalmente em navegadores de computadores (Desktop/PC).
- **Identificação do Cliente:** como o cliente não cria conta, ele é identificado pelo telefone informado no agendamento. O limite de 2 agendamentos por dia é controlado por esse telefone, e cada reserva recebe um código usado para cancelar ou remarcar.
- **Pagamento e Avisos:** o pagamento é feito no local, diretamente ao proprietário, e os avisos de realocação de horário são feitos pelo telefone cadastrado.
- **Funcionalidades Definidas pelo Grupo:** instrutores e aulas, loja (aluguel e venda de equipamentos), almoxarifado, notificações automáticas e gamificação não fazem parte do enunciado. São módulos complementares, fora do escopo desta versão, e só serão incorporados por solicitação de mudança aprovada, com atualização do cronograma e dos custos.
- **Perfil de Jogador:** a gamificação (módulo complementar) usará um perfil de jogador opcional; sem perfil, o agendamento continua anônimo.

## Restrições

- **Tecnológica:** o desenvolvimento do frontend deve utilizar estritamente o framework Flutter direcionado para a plataforma Web.
- **Prazo e custos:** a entrega do sistema está restrita ao calendário letivo do semestre (entrega final até 06/12/2026), utilizando infraestrutura de custo zero ou suportada por planos gratuitos.
- **Segurança de Acesso:** o acesso de escrita (gestão de quadras e agendamentos e, nos módulos complementares, almoxarifado e pontuação do ranking) é restrito aos proprietários via login e senha.
- **Consulta Pública:** a visualização de quadras e horários não pode exigir cadastro ou login, garantindo zero atrito no primeiro acesso do cliente.
- **Equipe:** composta por no máximo 5 pessoas.
- **Regra de negócio:** cada agendamento corresponde a 1 hora e cada cliente pode agendar no máximo 2 horários por dia. Também não deve ser obrigatória a participação no ranking por pontuação (parte gamificada).
- **Escopo:** funcionalidades não previstas no escopo aprovado precisam ser avaliadas e aprovadas antes de serem incorporadas.

## Licença

O projeto será disponibilizado sob licença de código aberto (MIT), permitindo fins educacionais e de estudo no âmbito da UFOP.
