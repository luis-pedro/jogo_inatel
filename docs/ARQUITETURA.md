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
| Mapa | `scripts/world/world.gd` | Ilha de grama (TileMapLayer montado por código), conversão célula↔mundo (grade de 64 px) e área construível. |
| Construção | `scripts/buildings/build_manager.gd`, `building.gd`, `building_data.gd` | Fantasma na grade, validação, custo e criação. Cada tipo de prédio é um `BuildingData` em `data/buildings/*.tres`. |
| Interface | `scripts/ui/hud.gd` | Recursos, população e botão de construir. |

Para adicionar um prédio novo: duplique `data/buildings/house.tres`, troque `textures` (uma por orientação), `door_directions`, `footprint` e `cost`.

## Autoloads

| Nome | Arquivo | Responsabilidade |
|---|---|---|
| `GameState` | `scripts/autoload/game_state.gd` | Recursos (comida, ouro, madeira), casas e população. Emite `resources_changed` e `population_changed`. |

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
