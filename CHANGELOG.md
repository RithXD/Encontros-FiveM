# Encontros-FiveM — Changelog

## [3.0.0] — Primeiro lançamento público — 2026-10-29

Sistema de criação, divulgação e premiação de encontros para servidores
QBCore. Administradores organizam os eventos pelo jogo; jogadores consultam os
encontros ativos, participam na área indicada e retiram suas premiações no NPC.

### Comandos

| Comando | Quem usa | Função |
| --- | --- | --- |
| `/encontrosadmin` | Grupos configurados em `Config.AdminGroups` (por padrão, `admin` e `god`) | Abre o painel para criar, encerrar ou cancelar encontros e administrar os locais aleatórios. |
| `/encontro` | Todos os jogadores | Abre a lista dos encontros ativos, com detalhes e opção de marcar o local no mapa. |

### Como funciona para os jogadores

1. Quando um encontro começa, os jogadores recebem um aviso e podem usar
   `/encontro` para consultar o evento e marcar sua posição.
2. A presença é verificada pelo servidor enquanto o jogador permanece dentro
   da área definida. Caso `Config.AttendanceVehicle.required` esteja ativo, ele
   também deve chegar usando um veículo próprio aceito pela configuração.
3. Para ter direito a prêmio, é obrigatório acumular pelo menos **60% da
   duração real** do evento dentro da área e estar presente quando ele terminar.
4. Após o encerramento, o prêmio pode ser retirado no NPC do evento durante
   10 minutos. Depois, a retirada passa para o NPC fixo configurado no servidor.
   O prazo total é de **24 horas** após o encerramento.

### Tipos de encontro

| Tipo | Uso | Premiação |
| --- | --- | --- |
| **Encontro** | Evento geral de carros, motos ou comunidade. | Disponível. |
| **Resenha** | Evento social, com ícone e identificação próprios no mapa. | Disponível. |
| **Marcador** | Apenas divulga um ponto no mapa. | Não possui premiação nem NPC de retirada. |

### Criando um encontro

Abra `/encontrosadmin`, acesse **Criar encontro**, preencha os campos abaixo e
selecione **Criar encontro**.

| Campo | Preenchimento e finalidade |
| --- | --- |
| **Nome** | Título exibido aos jogadores. Aceita até 100 caracteres. |
| **Foco** | Escolha entre **Encontro**, **Resenha** ou **Marcador**. O tipo Marcador não permite prêmio. |
| **Ícone no mapa** | Selecione um ícone da lista para o blip do encontro. |
| **ID do blip** | Alternativa para informar manualmente o ID numérico do ícone. Deve estar dentro dos limites definidos no servidor. |
| **Local** | Nome legível do ponto, como “Estacionamento do cassino”. Não é necessário quando o sorteio automático está ativo. |
| **Vector3 do início** | Centro da área do encontro no formato `vector3(x, y, z)`. Use o botão de mira para preencher com sua posição atual. Não é necessário no sorteio automático. |
| **Raio (m)** | Distância horizontal que delimita a área válida para participação. |
| **Altura (m)** | Tolerância vertical da área; use um valor maior em locais com níveis, rampas ou prédios. |
| **Descrição** | Texto exibido com as informações do encontro. Aceita até 500 caracteres. |
| **Sortear local automaticamente** | Usa um local cadastrado na aba **Locais aleatórios**. Quando marcado, preenche centro, NPC, raio, altura e nome a partir do ponto sorteado. |
| **Habilitar premiação** | Ativa ou desativa o prêmio do evento. Indisponível para Marcador. |
| **Categoria de premiação** | Escolha as peças de **carro**, as peças de **moto** ou **Premiação em dinheiro**. Cada jogador elegível recebe uma unidade de peça sorteada da categoria ou o valor em dinheiro definido. |
| **Dinheiro por jogador elegível** | Surge apenas para a categoria de dinheiro. Informe um valor inteiro dentro dos limites de `Config.MoneyReward`. O valor é pago em espécie (`cash`). |
| **NPC de retirada da premiação** | Necessário em encontros e resenhas com prêmio e local manual. Posicione o mecânico no mundo, mova com as setas, ajuste altura com `+`/`−`, rotação com a roda do mouse e confirme com `Enter`. `Esc` cancela. No local sorteado, o NPC cadastrado é usado automaticamente. |
| **Duração (min)** | Tempo de duração do encontro. Este valor é a base para o cálculo dos 60% de presença. |
| **Início** | Escolha **Iniciar agora** ou **Agendar horário**. |
| **Data e Horário** | Exibidos somente ao agendar; use `DD/MM/AAAA` e `HH:MM` em horário local. |
| **Repetir diariamente neste horário** | Cria a próxima ocorrência diária com os mesmos dados e premiação. Quando há mais de um local aleatório, o sistema tenta não repetir o último ponto. |

### Locais aleatórios

A aba **Locais aleatórios** reúne os pontos usados quando a opção de sorteio é
marcada na criação do encontro. As alterações são persistidas em
`Config.Locations` no `config.lua` e sincronizadas para os administradores.

| Campo | Preenchimento e finalidade |
| --- | --- |
| **Chave do local** | Identificador único do ponto. Use letras, números, espaços, `_` ou `-`. |
| **Nome do local** | Nome exibido quando este ponto for sorteado. |
| **Centro do evento (vector3)** | Centro da área do encontro. O botão de mira utiliza sua posição atual. |
| **Raio (m)** | Área horizontal válida para o encontro e sua presença. |
| **Posição e direção do NPC (vector4)** | Posição e rotação do NPC de retirada, no formato `vector4(x, y, z, heading)`. O botão de NPC usa sua posição e direção atuais. |
| **Altura (m)** | Tolerância vertical da área do ponto. |

### Premiações e segurança

- Peças de carro e moto são sorteadas a partir dos catálogos permitidos pelo
  servidor; caminhões permanecem bloqueados.
- O prêmio é associado ao personagem elegível e só pode ser entregue uma vez.
- Pagamentos em dinheiro usam a conta `cash`. Se houver falha durante a
  confirmação, o resgate fica em verificação para impedir pagamento duplicado;
  a equipe deve conferir o registro antes de liberá-lo.
- Eventos já criados preservam suas coordenadas e NPC, mesmo que o local
  aleatório de origem seja editado ou removido depois.

### Requisitos técnicos

- Dependências: `qb-core`, `qb-inventory`, `qb-target` e `oxmysql`.
- Para instalações novas, importe `setup.sql`. Em bancos existentes, o script
  executa as migrações necessárias ao iniciar.
- Ajustes de comandos, grupos administrativos, veículo próprio, valores de
  dinheiro, NPC fixo e locais padrão ficam em `config.lua`.
