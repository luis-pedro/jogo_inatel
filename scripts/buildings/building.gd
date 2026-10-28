class_name Building
extends Node2D
## Construção posta no mapa. A origem do nó é o canto inferior esquerdo da área ocupada
## no chão, para o y_sort ordenar os prédios pela base.

var data: BuildingData
var cell: Vector2i
## Índice da orientação (posição em `data.textures`).
var variant := 0

var _tile_size := 64

@onready var _sprite: Sprite2D = $Sprite2D


## Configura (ou reposiciona) o prédio. Pode ser chamado de novo depois de entrar na árvore.
func setup(building_data: BuildingData, origin_cell: Vector2i, tile_size: int, new_variant := 0) -> void:
	data = building_data
	cell = origin_cell
	variant = new_variant
	_tile_size = tile_size
	position = Vector2(origin_cell.x, origin_cell.y + data.footprint.y) * tile_size
	# Antes de _ready() o @onready ainda não existe; nesse caso o _ready() aplica o visual.
	if is_node_ready():
		_apply_sprite()


func _ready() -> void:
	_apply_sprite()


func _apply_sprite() -> void:
	var texture := data.textures[variant]
	_sprite.texture = texture
	_sprite.centered = false
	# Base do sprite na origem; sprite centralizado na largura da área ocupada.
	var footprint_width := data.footprint.x * _tile_size
	_sprite.offset = Vector2(-(texture.get_width() - footprint_width) / 2.0, -texture.get_height())
