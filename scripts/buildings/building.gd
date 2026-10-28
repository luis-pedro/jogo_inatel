class_name Building
extends Node2D
## Construção posta no mapa. A origem do nó é o canto inferior esquerdo da área ocupada
## no chão, para o y_sort ordenar os prédios pela base.

var data: BuildingData
var cell: Vector2i

var _tile_size := 64

@onready var _sprite: Sprite2D = $Sprite2D


## Configura (ou reposiciona) o prédio. Chamar antes de entrar na árvore da cena.
func setup(building_data: BuildingData, origin_cell: Vector2i, tile_size: int) -> void:
	data = building_data
	cell = origin_cell
	_tile_size = tile_size
	position = Vector2(origin_cell.x, origin_cell.y + data.footprint.y) * tile_size


func _ready() -> void:
	_sprite.texture = data.texture
	_sprite.centered = false
	# Base do sprite na origem; sprite centralizado na largura da área ocupada.
	var footprint_width := data.footprint.x * _tile_size
	_sprite.offset = Vector2(
		-(data.texture.get_width() - footprint_width) / 2.0,
		-data.texture.get_height()
	)
