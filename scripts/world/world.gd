class_name World
extends Node2D
## Mapa do reino: uma ilha de grama cercada de água, desenhada com o tileset do Tiny Swords.
## Também guarda quais células estão bloqueadas (prédios, árvores) ou ocupadas por animais e
## faz o pathfinding.

const TILE_SIZE := 64
const MAP_SIZE := Vector2i(40, 24)  # em tiles
const GRASS_TEXTURE := preload("res://assets/Terrain/Tileset/Tilemap_color1.png")

var _blocked: Dictionary = {}  # Vector2i -> true
## Células com um animal: não dá para construir nelas, mas os aldeões passam.
var _occupied: Dictionary = {}  # Vector2i -> true
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


func occupy_cell(cell: Vector2i) -> void:
	_occupied[cell] = true


func release_cell(cell: Vector2i) -> void:
	_occupied.erase(cell)


## Dentro da ilha e sem nada ocupando a célula: dá para construir ou colocar algo.
func is_cell_free(cell: Vector2i) -> bool:
	return is_buildable(cell) and not is_blocked(cell) and not _occupied.has(cell)


func is_point_walkable(point: Vector2) -> bool:
	var cell := world_to_cell(point)
	return is_buildable(cell) and not is_blocked(cell)


## Se o ponto estiver bloqueado, devolve o centro da célula livre mais próxima.
func nearest_free_point(point: Vector2) -> Vector2:
	var cell := world_to_cell(point)
	if _is_walkable_cell(cell):
		return point
	return cell_to_center(_nearest_walkable_cell(cell))


## Caminho de `from_point` até exatamente `to_point`, passando pelos centros das células.
## Vazio se não houver caminho (ex.: destino bloqueado ou cercado).
func find_path(from_point: Vector2, to_point: Vector2) -> PackedVector2Array:
	var path := find_path_to_any(from_point, [world_to_cell(to_point)])
	if not path.is_empty():
		# O último passo vai ao ponto em si, e não ao centro da célula onde ele está.
		path[path.size() - 1] = to_point
	return path


## Caminho de `from_point` até uma célula vizinha livre de `target_cell`.
## Serve para ir até algo que ocupa uma célula, como uma árvore. Prefere os lados (onde o golpe
## aparece melhor), depois a frente (o aldeão cobre o alvo) e por último atrás (o alvo cobre o
## aldeão). Vazio se não houver caminho.
func find_path_to_adjacent(from_point: Vector2, target_cell: Vector2i) -> PackedVector2Array:
	for sides: Array in [[Vector2i.LEFT, Vector2i.RIGHT], [Vector2i.DOWN], [Vector2i.UP]]:
		var goals: Array[Vector2i] = []
		for side in sides:
			goals.append(target_cell + (side as Vector2i))
		var path := find_path_to_any(from_point, goals)
		if not path.is_empty():
			return path
	return PackedVector2Array()


## Menor caminho de `from_point` até qualquer uma das células `goals` que esteja livre.
func find_path_to_any(from_point: Vector2, goals: Array[Vector2i]) -> PackedVector2Array:
	var current_cell := world_to_cell(from_point)
	# Quem está num lugar bloqueado (ex.: marcaram uma obra em cima) parte da célula livre ao lado.
	var from_cell := current_cell if _is_walkable_cell(current_cell) else _nearest_walkable_cell(current_cell)
	if not _is_walkable_cell(from_cell):
		return PackedVector2Array()

	var best: Array[Vector2i] = []
	for goal in goals:
		if not _is_walkable_cell(goal):
			continue
		var ids := _astar.get_id_path(from_cell, goal)
		if not ids.is_empty() and (best.is_empty() or ids.size() < best.size()):
			best = ids
	return _ids_to_points(best, current_cell)


func _is_walkable_cell(cell: Vector2i) -> bool:
	return _astar.is_in_boundsv(cell) and not _astar.is_point_solid(cell)


## Célula livre mais próxima, procurando em anéis cada vez maiores. Devolve a própria se não achar.
func _nearest_walkable_cell(cell: Vector2i) -> Vector2i:
	for radius in range(1, 4):
		var best := cell
		var best_distance := INF
		for x in range(-radius, radius + 1):
			for y in range(-radius, radius + 1):
				var candidate := cell + Vector2i(x, y)
				var distance := Vector2(x, y).length()
				if _is_walkable_cell(candidate) and distance < best_distance:
					best = candidate
					best_distance = distance
		if best != cell:
			return best
	return cell


func _ids_to_points(ids: Array[Vector2i], current_cell: Vector2i) -> PackedVector2Array:
	var points := PackedVector2Array()
	# Se o caminho começa na célula onde o aldeão já está, pula para ele não "voltar" ao centro dela.
	var skip_first := ids.size() > 1 and ids[0] == current_cell
	for i in range(1 if skip_first else 0, ids.size()):
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
