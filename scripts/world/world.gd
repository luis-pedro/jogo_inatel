class_name World
extends Node2D
## Mapa do reino: uma ilha de grama cercada de água, desenhada com o tileset do Tiny Swords.
## Também guarda quais células estão bloqueadas (prédios, árvores) e faz o pathfinding.

const TILE_SIZE := 64
const MAP_SIZE := Vector2i(40, 24)  # em tiles
const GRASS_TEXTURE := preload("res://assets/Terrain/Tileset/Tilemap_color1.png")

var _blocked: Dictionary = {}  # Vector2i -> true
var _astar := AStarGrid2D.new()

@onready var _ground: TileMapLayer = $Ground


func _ready() -> void:
	_ground.tile_set = _build_tile_set()
	_paint_island()
	_build_pathfinding_grid()


## Retângulo do mundo em pixels (usado para limitar a câmera).
func get_world_rect() -> Rect2i:
	var margin := TILE_SIZE * 4
	return Rect2i(Vector2i.ZERO, MAP_SIZE * TILE_SIZE).grow(margin)


func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell * TILE_SIZE)


func cell_to_center(cell: Vector2i) -> Vector2:
	return cell_to_world(cell) + Vector2(TILE_SIZE, TILE_SIZE) / 2.0


func world_to_cell(point: Vector2) -> Vector2i:
	return Vector2i((point / TILE_SIZE).floor())


## O anel externo de tiles é a borda da ilha (fica fora da área construível).
func is_buildable(cell: Vector2i) -> bool:
	return cell.x >= 1 and cell.y >= 1 \
			and cell.x < MAP_SIZE.x - 1 and cell.y < MAP_SIZE.y - 1


func get_center_cell() -> Vector2i:
	return MAP_SIZE / 2


## Marca a célula como ocupada (prédio, árvore...): ninguém constrói nem anda nela.
func block_cell(cell: Vector2i) -> void:
	_blocked[cell] = true
	if _astar.is_in_boundsv(cell):
		_astar.set_point_solid(cell, true)


## Desfaz o `block_cell` (ex.: uma árvore foi arrancada): volta a poder construir e andar na célula.
func unblock_cell(cell: Vector2i) -> void:
	_blocked.erase(cell)
	if _astar.is_in_boundsv(cell) and is_buildable(cell):
		_astar.set_point_solid(cell, false)


func is_blocked(cell: Vector2i) -> bool:
	return _blocked.has(cell)


## Dentro da ilha e sem nada ocupando a célula.
func is_cell_free(cell: Vector2i) -> bool:
	return is_buildable(cell) and not is_blocked(cell)


func is_point_walkable(point: Vector2) -> bool:
	return is_cell_free(world_to_cell(point))


## Caminho (centros de células) de `from_point` até a célula de `to_point`.
## Vazio se não houver caminho (ex.: destino bloqueado ou cercado).
func find_path(from_point: Vector2, to_point: Vector2) -> PackedVector2Array:
	var from_cell := world_to_cell(from_point)
	var to_cell := world_to_cell(to_point)
	if not _is_walkable_cell(from_cell) or not _is_walkable_cell(to_cell):
		return PackedVector2Array()
	return _ids_to_points(_astar.get_id_path(from_cell, to_cell))


## Caminho de `from_point` até uma célula vizinha livre de `target_cell`.
## Serve para ir até algo que ocupa uma célula, como uma árvore. Vazio se não houver caminho.
func find_path_to_adjacent(from_point: Vector2, target_cell: Vector2i) -> PackedVector2Array:
	var from_cell := world_to_cell(from_point)
	if not _is_walkable_cell(from_cell):
		return PackedVector2Array()

	var best: Array[Vector2i] = []
	for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var neighbor: Vector2i = target_cell + direction
		if not _is_walkable_cell(neighbor):
			continue
		var ids := _astar.get_id_path(from_cell, neighbor)
		if not ids.is_empty() and (best.is_empty() or ids.size() < best.size()):
			best = ids
	return _ids_to_points(best)


func _is_walkable_cell(cell: Vector2i) -> bool:
	return _astar.is_in_boundsv(cell) and not _astar.is_point_solid(cell)


func _ids_to_points(ids: Array[Vector2i]) -> PackedVector2Array:
	var points := PackedVector2Array()
	# O primeiro ponto é a célula onde o aldeão já está; pula para ele não "voltar" ao centro dela.
	for i in range(1 if ids.size() > 1 else 0, ids.size()):
		points.append(cell_to_center(ids[i]))
	return points


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


## Grade do A*: tudo fora da área construível (água, borda) é parede.
func _build_pathfinding_grid() -> void:
	_astar.region = Rect2i(Vector2i.ZERO, MAP_SIZE)
	_astar.cell_size = Vector2(TILE_SIZE, TILE_SIZE)
	# Diagonal só quando não há quina no caminho, para não "cortar" cantos de casas.
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.update()
	for x in MAP_SIZE.x:
		for y in MAP_SIZE.y:
			if not is_buildable(Vector2i(x, y)):
				_astar.set_point_solid(Vector2i(x, y), true)
