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
| Madeira | Construções | Árvores | `Terrain/Resources/Wood` |

Valores iniciais provisórios (em `scripts/autoload/game_state.gd`): **50 comida, 20 ouro, 100 madeira**.

## 4. População

- Cada **casa** construída gera **2 aldeões** (Pawns).
- O jogo começa com 1 casa → 2 aldeões.
- Aldeões coletam recursos e constroem estruturas **[A definir]**.

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

**Controles (v1):** WASD/setas movem a câmera · arrastar com o botão esquerdo ou do meio move a câmera (o esquerdo só fora do modo de construção) · roda do mouse dá zoom · **B** (ou botão) constrói casa · **R** gira a casa (3 orientações) · clique esquerdo confirma · clique direito/Esc cancela · **F1** (build de debug) dá +50 de cada recurso.

- Contadores de recursos (comida, ouro, madeira) e população.
- Menu de construção.
- **[A definir]**

## 11. Histórico de decisões

| Data | Decisão |
|---|---|
| 2026-10-27 | Início do projeto. Godot 4.7, assets Tiny Swords, renderer Compatibility. |
| 2026-10-28 | v1: câmera 2D (a visão diagonal vem da arte 3/4 do Tiny Swords) e construção de casas em grade de 64 px. |
