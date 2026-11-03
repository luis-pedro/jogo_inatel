# Arquitetura e convenções

## Decisões técnicas

| Decisão | Motivo |
|---|---|
| **Godot 4.7**, GDScript | Versão que a equipe já usa. |
| Renderer **Compatibility** (OpenGL) | Jogo 2D não precisa do Forward+; roda em PCs mais fracos (ex.: máquinas da feira) e permite exportar para web (itch.io). |
| Filtro de textura **Nearest** | Mantém o pixel art nítido. |
| Viewport 1280×720, stretch `canvas_items` / `expand` | Escala para qualquer resolução sem distorcer. |

## Organização de pastas

- `assets/` — arte e áudio. Não renomear os arquivos do Tiny Swords (facilita atualizar o pack).
- `scenes/<funcionalidade>/` — cada cena junto do que for exclusivo dela. Ex.: `scenes/buildings/house/house.tscn`.
- `scripts/` — scripts compartilhados ou que não pertencem a uma cena específica.
- `scripts/autoload/` — singletons globais.

Scripts ligados a uma única cena podem ficar na mesma pasta da cena (`house.tscn` + `house.gd`).

## Sistemas principais

| Sistema | Arquivos | Descrição |
|---|---|---|
| Câmera | `scripts/camera/game_camera.gd` | Pan, zoom e limites do mapa. |
| Mapa | `scripts/world/world.gd` | Ilha de grama (TileMapLayer montado por código), conversão célula↔mundo (grade de 64 px), células bloqueadas (prédios, árvores) e **pathfinding** com `AStarGrid2D`. |
| Construção | `scripts/buildings/build_manager.gd`, `building.gd`, `building_data.gd` | Fantasma na grade, validação, custo e criação. Cada tipo de prédio é um `BuildingData` em `data/buildings/*.tres`. |
| Aldeões | `scripts/units/pawn.gd` | Máquina de estados IDLE ⇄ WALK (passeio) e TO_TREE → CHOP (tarefa de cortar). Anima por código a partir das faixas de frames. |
| Recursos coletáveis | `scripts/resources/wood_tree.gd` | Árvore (`Area2D` na camada `collectibles`): madeira restante, `worker` (quem corta) e toco ao acabar. |
| Sprites | `scripts/core/sprite_sheets.gd` | `SpriteSheets.add_animation()` fatia faixas horizontais de frames em `SpriteFrames`. |
| Interface | `scripts/ui/hud.gd` | Recursos, população e botão de construir. |

Para adicionar um prédio novo: duplique `data/buildings/house.tres`, troque `textures` (uma por orientação), `door_directions`, `footprint` e `cost`.

## Camadas

**Ordem de desenho** (em `main.tscn`, de baixo para cima):

| Nó | Conteúdo |
|---|---|
| `Water` | Fundo de água (`z_index = -10`). |
| `World/Ground` | Chão (TileMapLayer). Nunca se sobrepõe. |
| `Entities` (y-sort) | Tudo que fica em pé no chão e pode se sobrepor: prédios, aldeões, inimigos, árvores, minas. **Precisam estar no mesmo nó** para o y-sort funcionar. |
| `Overlay` | Fantasma de construção, seleção, efeitos. Desenhado acima de tudo no mundo. |
| `Hud` (CanvasLayer) | Interface, sempre por cima. |

Para achar um tipo de objeto sem depender da hierarquia, use **grupos** (`PhysicsLayers.GROUP_UNITS`, `GROUP_BUILDINGS`...): `get_tree().get_nodes_in_group(PhysicsLayers.GROUP_UNITS)`.

**Camadas de física 2D** (nomeadas em Project Settings > Layer Names; constantes em `scripts/core/physics_layers.gd`):

| # | Nome | Para quê |
|---|---|---|
| 1 | `units` | Pawn, guerreiro, arqueiro... |
| 2 | `enemies` | Inimigos |
| 3 | `buildings` | Construções |
| 4 | `collectibles` | Árvores, ouro, carne |
| 5 | `terrain` | Água, penhascos |
| 6 | `projectiles` | Flechas |

*Layer* = o que o objeto **é**; *mask* = o que ele **enxerga**. Ex.: uma flecha inimiga tem `collision_layer = PROJECTILES` e `collision_mask = UNITS | BUILDINGS`.

## Tela

Tela cheia por padrão (`window/size/mode = Fullscreen`), **F11** alterna para janela. Resolução base 1920×1080 com stretch `canvas_items`/`expand`: em telas Full HD o pixel art fica 1:1, e em outras resoluções a imagem escala mantendo a proporção.

## Autoloads

| Nome | Arquivo | Responsabilidade |
|---|---|---|
| `GameState` | `scripts/autoload/game_state.gd` | Recursos (comida, ouro, madeira), casas e população. Emite `resources_changed` e `population_changed`. |

**Aldeões disponíveis:** `GameState.population` é o total e `busy_villagers` os ocupados; `available_villagers()` é a diferença. Quem começa uma tarefa chama `reserve_villager()` e quem termina chama `release_villager()`. O sinal `villagers_changed` atualiza o HUD.

**Clique vs. arrasto:** o botão esquerdo também move a câmera, então `main.gd` só trata como clique se o mouse soltar a até 8 px de onde apertou. O `BuildManager` marca seus cliques como tratados (`set_input_as_handled`) para não virarem seleção.

Exemplo de uso:

```gdscript
const HOUSE_COST := {"wood": 20}

func try_build_house() -> void:
	if GameState.spend(HOUSE_COST):
		GameState.add_house()
```

## Convenções de código

Segue o [guia de estilo oficial do GDScript](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html):

| Elemento | Padrão | Exemplo |
|---|---|---|
| Arquivos e pastas | `snake_case` | `game_state.gd`, `main.tscn` |
| Classes (`class_name`) e nós | `PascalCase` | `Building`, `Camera2D` |
| Funções e variáveis | `snake_case` | `add_resource()` |
| Constantes | `CONSTANT_CASE` | `VILLAGERS_PER_HOUSE` |
| Sinais | `snake_case`, no passado | `resources_changed` |
| Funções/variáveis privadas | prefixo `_` | `_update_hud()` |

- Indentação com **tabs**.
- Use **tipagem estática** (`var x: int`, `-> void`).
- Código e identificadores em **inglês**; comentários e documentação em **português**.
- Prefira **sinais** para comunicar "para cima" (filho → pai) e chamadas diretas "para baixo".
