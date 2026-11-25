# Game Design Document (GDD)

> Documento vivo: atualize sempre que uma mecânica for definida ou alterada.
> Itens marcados com **[A definir]** ainda precisam de decisão da equipe.

## 1. Visão geral

| | |
|---|---|
| **Gênero** | Tower defense + construção de reino / gestão de recursos |
| **Perspectiva** | 2D top-down |
| **Engine** | Godot 4.7 |
| **Plataforma alvo** | PC (Windows); build web para o itch.io **[A definir]** |
| **Referências** | *Kingdoms and Castles*, *Northgard* |
| **Objetivo do projeto** | Apresentação e competição na FETIN |

### Conceito

O jogador comanda um pequeno reino que começa com **uma casa e dois aldeões**. Coletando recursos e construindo novas estruturas, ele expande o território enquanto se prepara para ataques de inimigos. Unidades militares protegem o reino e permitem conquistar novas áreas.

## 2. Loop principal

```
Coletar recursos ──► Construir / Recrutar ──► Expandir território
        ▲                                            │
        └──────── Defender-se dos inimigos ◄─────────┘
```

## 3. Recursos

| Recurso | Uso principal | Fonte | Asset |
|---|---|---|---|
| Comida | Manter a população **[A definir]** | Ovelhas (abatidas por aldeões) | `Terrain/Resources/Meat` |
| Ouro | Treinar tropas **[A definir]** | Veios de minério (minerados por aldeões) | `Terrain/Resources/Gold` |
| Madeira | Construções | Árvores (4 tipos, sorteados no mapa; cada uma deixa o toco do seu tipo) | `Terrain/Resources/Wood` |

Valores iniciais provisórios (em `scripts/autoload/game_state.gd`): **50 comida, 20 ouro, 100 madeira**.

## 4. População

- Cada **casa** construída gera **2 aldeões** (Pawns).
- O jogo começa com 1 casa → 2 aldeões.
- Sem tarefa, o aldeão passeia: anda até um ponto perto de casa, para (idle) e repete.
- O HUD mostra os aldeões **disponíveis / no total**. Aldeão ocupado com uma tarefa não está disponível.
- **Coleta de madeira:** clicar numa árvore manda o aldeão disponível com o caminho mais curto até ela. Ele corta (2 de madeira por machadada) até encher a **mochila (13)** ou a árvore acabar, leva a madeira até a **porta da casa** com a animação de carregar, entrega (só então o estoque sobe) e volta à árvore enquanto houver madeira. Ao acabar vira toco e ele volta a ficar disponível. **O toco volta a ser árvore** depois de um tempo sorteado conforme o tipo: **90 a 150 s** nas grandes (Tree1/2) e **30 a 60 s** nas pequenas (Tree3/4), diferente a cada árvore e a cada corte; a muda cresce com uma pequena animação e a madeira é sorteada de novo. Enquanto é toco, a célula continua ocupada. Só um aldeão por árvore (reservada durante todas as viagens).
- Consumo de comida pela população **[A definir]**.
- **Madeira por árvore (sorteada, e sorteada de novo a cada rebrota):** árvores grandes (Tree1 e Tree2) dão **14 a 25** e exigem **2 viagens**; árvores pequenas (Tree3 e Tree4) dão **5 a 12** e exigem **1 viagem**. Uma casa custa 20, então uma árvore grande rende cerca de uma casa. As viagens vêm da mochila (13) contra a madeira da árvore; os valores ficam em `data/trees/*.tres` (`wood_min`/`wood_max`) e `BACKPACK_CAPACITY` em `pawn.gd`.
- **Floresta inicial:** o mapa começa com **50 árvores** espalhadas aleatoriamente (4 tipos), com uma clareira de 6 células em volta da casa inicial.
- **Arrancar o toco:** clicar num **toco** manda um aldeão arrancá-lo (3 machadadas). A árvore **some do jogo de vez**, a célula fica livre para construir e o aldeão recebe **2 a 5 de madeira** (entregue na casa como o resto). Serve para abrir espaço.
- **Toco reservado não cresce:** assim que o jogador dá a ordem, a contagem de crescimento do toco **pausa** até o aldeão terminar. Se mesmo assim a árvore voltar a ser adulta antes de ele chegar, ele **corta a árvore primeiro** (se a muda ainda está crescendo, espera) e depois arranca o toco.
- **Construção por aldeões:** ao confirmar uma casa, o custo é pago, o terreno é reservado e o aldeão livre mais próximo vai até a obra e martela por **8 s**. O terreno vira um **canteiro de obras** (terra, estacas e corda); quando o aldeão chega a casa é erguida de baixo para cima, com poeira e barra de progresso. Os **2 novos aldeões só nascem quando a obra termina**. Sem aldeão livre (ou sem caminho até a obra) a construção é recusada com um aviso, sem gastar madeira.
- **Veios de ouro:** 2 veios de 3 a 4 minérios encostados (6 a 8 no mapa), longe da casa inicial (o veio nasce a 10 células ou mais) e uns dos outros, sem árvores em volta. São bem mais raros que as árvores e **não renascem**: o minério esgotado some e libera a célula.
- **Mineração:** clicar num minério (o cursor vira picareta) manda o aldeão livre mais próximo. A quantidade de ouro é sorteada pelo tamanho do minério, com mochila de **30**: pequeno **20 a 30** (1 viagem), médio **40 a 60** (2 viagens), grande **70 a 90** (3 viagens). Ele tira 4 por golpe e entrega na casa.
- **Rebanhos:** 3 rebanhos de 3 a 4 ovelhas, a 7 células ou mais da casa (centro do rebanho), em pastos sem árvores. As ovelhas **andam em bando**: o grupo se desloca pelo pasto a cada 7 a 12 s e cada ovelha fica a até 2 células do centro dele, parando para comer grama. Não dá para construir em cima delas, mas os aldeões passam. **Reprodução:** se há pelo menos **duas ovelhas adultas juntas** (até 3 células) no mesmo rebanho e falta alguma, nasce uma a cada 45 a 90 s; ela aparece pequena e cresce. O rebanho **nunca passa da quantidade com que começou**. Um rebanho que fique com uma ovelha ou nenhuma não se recupera.
- **Caça:** clicar numa ovelha (o cursor vira faca) manda o aldeão livre mais próximo. Ela para, ele a abate com 3 golpes, a carne fica no chão e ele a leva para casa com mochila de **15**. Cada ovelha dá **12 a 30** de comida (sorteado): 1 ou 2 viagens.
- **Planejado:** a mochila já existe (capacidade fixa em `pawn.gd`); falta a madeira que não couber cair no mapa como item (`Terrain/Resources/Wood/Wood Resource`) e fica esperando até um aldeão buscá-la. Hoje a madeira vai direto para o estoque.

## 5. Construções

Assets disponíveis em `assets/Buildings/<Cor> Buildings/`:

| Construção | Função | Custo |
|---|---|---|
| House (1–3) | +2 aldeões | 20 madeira *(provisório)* |
| Castle | Centro do reino **[A definir]** | — |
| Barracks | Treina Warriors / Lancers **[A definir]** | **[A definir]** |
| Archery | Treina Archers **[A definir]** | **[A definir]** |
| Monastery | Treina Monks (cura) **[A definir]** | **[A definir]** |
| Tower | Defesa **[A definir]** | **[A definir]** |

## 6. Unidades

Assets disponíveis em `assets/Units/<Cor> Units/`:

| Unidade | Papel |
|---|---|
| Pawn | Aldeão: coleta e construção |
| Warrior | Combate corpo a corpo |
| Lancer | Combate corpo a corpo **[A definir]** |
| Archer | Ataque à distância |
| Monk | Suporte / cura **[A definir]** |

## 7. Inimigos

**[A definir]** — tipos, comportamento, ondas, de onde vêm. Possibilidade: usar outra cor de facção do Tiny Swords (ex.: Red ou Black) como inimigos.

## 8. Território e expansão

**[A definir]** — como o território é representado e conquistado.

## 9. Condições de vitória e derrota

**[A definir]**

## 10. Interface (HUD)

**Controles (v1):** WASD/setas movem a câmera · arrastar com o botão esquerdo ou do meio move a câmera (o esquerdo só fora do modo de construção) · roda do mouse dá zoom · **B** (ou botão) constrói casa · **R** gira a casa (3 orientações) · clique esquerdo confirma / **clique numa árvore manda cortar** (o cursor vira um machado sobre árvores cortáveis) · clique direito/Esc cancela · **F11** alterna tela cheia/janela · **F1** (build de debug) dá +50 de cada recurso.

- Contadores de recursos (comida, ouro, madeira) e população.
- Menu de construção.
- **[A definir]**

## 11. Histórico de decisões

| Data | Decisão |
|---|---|
| 2026-10-27 | Início do projeto. Godot 4.7, assets Tiny Swords, renderer Compatibility. |
| 2026-11-03 | Coleta de madeira: árvores no cenário de teste, tarefa de cortar e contador de aldeões disponíveis. |
| 2026-10-28 | v1: câmera 2D (a visão diagonal vem da arte 3/4 do Tiny Swords) e construção de casas em grade de 64 px. |
