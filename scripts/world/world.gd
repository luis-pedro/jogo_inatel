class_name World
extends Node2D
## Mapa do reino: uma ilha de grama cercada de água, desenhada com o tileset do Tiny Swords.

const TILE_SIZE := 64
const MAP_SIZE := Vector2i(40, 24)  # em tiles
const GRASS_TEXTURE := preload("res://assets/Terrain/Tileset/Tilemap_color1.png")

@onready var _ground: TileMapLayer = $Ground


func _ready() -> void:
	_ground.tile_set = _build_tile_set()
	_paint_island()


## Retângulo do mundo em pixels (usado para limitar a câmera).
func get_world_rect() -> Rect2i:
	var margin := TILE_SIZE * 4
	return Rect2i(Vector2i.ZERO, MAP_SIZE * TILE_SIZE).grow(margin)


func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell * TILE_SIZE)


func world_to_cell(point: Vector2) -> Vector2i:
	return Vector2i((point / TILE_SIZE).floor())


## O anel externo de tiles é a borda da ilha (fica fora da área construível).
func is_buildable(cell: Vector2i) -> bool:
	return cell.x >= 1 and cell.y >= 1 \
			and cell.x < MAP_SIZE.x - 1 and cell.y < MAP_SIZE.y - 1


func get_center_cell() -> Vector2i:
	return MAP_SIZE / 2


## O bloco 3x3 do canto superior esquerdo do tilemap é a grama com bordas.
func _build_tile_set() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	var source := TileSetAtlasSource.new()
	source.texture = GRASS_TEXTURE
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for x in 3:
		for y in 3:
			source.create_tile(Vector2i(x, y))
	tile_set.add_source(source, 0)
	return tile_set


func _paint_island() -> void:
	for x in MAP_SIZE.x:
		for y in MAP_SIZE.y:
			var atlas := Vector2i(_edge_index(x, MAP_SIZE.x), _edge_index(y, MAP_SIZE.y))
			_ground.set_cell(Vector2i(x, y), 0, atlas)


## 0 = borda inicial, 1 = miolo, 2 = borda final.
func _edge_index(value: int, size: int) -> int:
	if value == 0:
		return 0
	if value == size - 1:
		return 2
	return 1
