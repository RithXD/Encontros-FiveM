# Encontros-FiveM

Veja a [documentação de funcionamento e revisão técnica](docs/FUNCIONAMENTO_E_REVISAO.md)
para a arquitetura, os fluxos, as limitações verificadas e as melhorias priorizadas.

No painel `/encontrosadmin`, selecione **Resenha** como tipo de evento e
**Premiação em dinheiro** como categoria de premiação. Informe o valor em espécie
por jogador elegível e posicione o NPC de retirada. Peças de carro e moto continuam
disponíveis como categorias de premiação.

Todas as premiações exigem pelo menos **60% da duração real do evento**, somando
os períodos de presença verificados pelo servidor, e presença no encerramento.
Um evento encerrado após 20 minutos exige 12 minutos de presença. A verificação
de chegada com veículo próprio continua seguindo `Config.AttendanceVehicle`.

Configure os valores permitidos em `config.lua`:

```lua
Config.MoneyReward = { minimum = 1, maximum = 1000000, default = 1000 }
```

O valor escolhido é individual, inteiro e validado no servidor. Eventos recorrentes
mantêm a categoria e o valor. Os prêmios ficam no NPC do evento por 10 minutos após
o encerramento e depois no NPC fixo, até completar 24 horas do encerramento.

Reinicie o recurso para carregar as alterações. O esquema é atualizado
automaticamente na inicialização, adicionando `encontros.reward_money` aos bancos
existentes. `setup.sql` contém o esquema para instalações novas.

Na aba **Locais aleatórios**, cadastre, edite ou remova os pontos usados pelo
modo “Sortear local automaticamente”. Cada ponto tem chave única, nome, centro
em `vector3`, posição e direção do NPC em `vector4`, raio e tolerância de altura.
Os botões de posição usam a posição atual do admin, incluindo a direção do NPC.

Cada alteração salva diretamente em `Config.Locations` de `config.lua`, mantendo
a indentação, as quebras de linha, os comentários e as entradas não alteradas.
Novas entradas usam `key`, `label`, `coords`, `npc`, `radius` e `heightTolerance`,
na mesma ordem do arquivo. O servidor verifica a gravação e atualiza o sorteio e
os painéis administrativos conectados imediatamente. Eventos já criados mantêm
as posições que receberam ao serem criados.

Antes de gravar, o recurso mantém a versão anterior em `config.lua.locations.bak`.
Se outro admin editar a lista enquanto você edita um local, selecione o local
novamente para revisar a versão atual. Se editar `Config.Locations` manualmente
no arquivo, reinicie o recurso para carregar essa mudança; o painel recusa
sobrescrever alterações manuais ainda não carregadas.

Pagamentos usam `Player.Functions.AddMoney` do QBCore na conta `cash` e solicitam o salvamento
do personagem. Uma reserva persistida evita crédito duplicado. Se o processo ou
o banco falhar durante um pagamento, o resgate fica com status `paying` e a mensagem
“Pagamento em verificação”. A administração deve conferir o saldo salvo e o log
`encontros-reward-<id>` antes de concluir ou liberar esse resgate; ele não é
repetido automaticamente. O saldo online do QBCore e a tabela de resgates não
participam de uma única transação.

Testes locais (Node.js com `fengari` disponível):

```sh
node --test tests/locations.test.cjs tests/policy.test.cjs tests/server.test.cjs tests/ui.test.cjs tests/client_npc.test.cjs tests/client_notice.test.cjs
```

`tests/catalog.test.cjs` também verifica os itens instaláveis e depende dos arquivos
locais de `qb-core` e `jv-retifica` no caminho indicado pelo teste.
