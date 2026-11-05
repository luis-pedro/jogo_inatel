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
| Comida | Manter a população **[A definir]** | **[A definir]** | `Terrain/Resources/Meat` |
| Ouro | Recrutar unidades **[A definir]** | Minas de ouro | `Terrain/Resources/Gold` |
| Madeira | Construções | Árvores (4 tipos, sorteados no mapa; cada uma deixa o toco do seu tipo) | `Terrain/Resources/Wood` |

Valores iniciais provisórios (em `scripts/autoload/game_state.gd`): **50 comida, 20 ouro, 100 madeira**.

## 4. População

- Cada **casa** construída gera **2 aldeões** (Pawns).
- O jogo começa com 1 casa → 2 aldeões.
- Sem tarefa, o aldeão passeia: anda até um ponto perto de casa, para (idle) e repete.
- O HUD mostra os aldeões **disponíveis / no total**. Aldeão ocupado com uma tarefa não está disponível.
- **Coleta de madeira:** clicar numa árvore manda o aldeão disponível com o caminho mais curto até ela. Ele corta (2 de madeira por machadada) até encher a **mochila (13)** ou a árvore acabar, leva a madeira até a **porta da casa** com a animação de carregar, entrega (só então o estoque sobe) e volta à árvore enquanto houver madeira. Ao acabar vira toco e ele volta a ficar disponível. **O toco volta a ser árvore** depois de um tempo sorteado conforme o tipo: **90 a 150 s** nas grandes (Tree1/2) e **30 a 60 s** nas pequenas (Tree3/4), diferente a cada árvore e a cada corte; a muda cresce com uma pequena animação e a madeira é sorteada de novo. Enquanto é toco, a célula continua ocupada. Só um aldeão por árvore (reservada durante todas as viagens).
- Coleta de comida/ouro e construção por aldeões **[A definir]**.
- **Madeira por árvore (sorteada, e sorteada de novo a cada rebrota):** árvores grandes (Tree1 e Tree2) dão **14 a 25** e exigem **2 viagens**; árvores pequenas (Tree3 e Tree4) dão **5 a 12** e exigem **1 viagem**. Uma casa custa 20, então uma árvore grande rende cerca de uma casa. As viagens vêm da mochila (13) contra a madeira da árvore; os valores ficam em `data/trees/*.tres` (`wood_min`/`wood_max`) e `BACKPACK_CAPACITY` em `pawn.gd`.
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
