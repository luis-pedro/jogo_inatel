extends Node2D
## Cena principal: monta o mapa, a câmera, a construção e a interface.

## Quanto o mouse pode se mover (em px) entre apertar e soltar e ainda contar como clique.
## Acima disso é um arrasto (da câmera).
const CLICK_DRAG_THRESHOLD := 8.0

## Cursor mostrado sobre cada recurso que dá para coletar: machado na árvore, picareta no ouro
## e faca na ovelha.
const TOOL_CURSOR_TEXTURES := {
	"wood": preload("res://assets/Terrain/Resources/Tools/Tool_02.png"),
	"gold": preload("res://assets/Terrain/Resources/Tools/Tool_04.png"),
	"food": preload("res://assets/Terrain/Resources/Tools/Tool_03.png"),
}
const TOOL_CURSOR_SIZE := 80

## Tipos de árvore sorteados ao criar o cenário (cada um com seu toco).
const TREE_TYPES := [
	preload("res://data/trees/tree1.tres"),
	preload("res://data/trees/tree2.tres"),
	preload("res://data/trees/tree3.tres"),
	preload("res://data/trees/tree4.tres"),
]

## Tipos de minério de ouro: 1 e 2 pequenos, 3 e 4 médios, 5 e 6 grandes.
const GOLD_TYPES := [
	preload("res://data/gold/gold1.tres"),
	preload("res://data/gold/gold2.tres"),
	preload("res://data/gold/gold3.tres"),
	preload("res://data/gold/gold4.tres"),
	preload("res://data/gold/gold5.tres"),
	preload("res://data/gold/gold6.tres"),
]

## O ouro nasce em poucos veios (grupos de minérios vizinhos), longe da casa e uns dos outros.
const GOLD_VEIN_COUNT := 2
const GOLD_PER_VEIN := Vector2i(3, 4)  # mín., máx.
const GOLD_CLEARING_RADIUS := 10.0
const GOLD_VEIN_SPACING := 10.0
## Distância (em células) em volta do ouro onde não nascem árvores, para dar acesso ao veio.
const GOLD_TREE_MARGIN := 1.5

## As ovelhas vivem em rebanhos, num pasto sem árvores em volta (ver `Flock`).
const FLOCK_COUNT := 3
const SHEEP_PER_FLOCK := Vector2i(3, 4)  # mín., máx.
const FLOCK_CLEARING_RADIUS := 7.0
const FLOCK_SPACING := 9.0
## Distância (em células) em volta do pasto onde não nascem árvores.
const PASTURE_TREE_MARGIN := 4.5

## Quantas árvores nascem no mapa e quão longe da casa inicial (em células) fica a clareira
## onde não nasce nenhuma, para o começo não ficar apertado.
const TREE_COUNT := 50
const START_CLEARING_RADIUS := 6.0

@export var house_data: BuildingData
@export var pawn_scene: PackedScene
@export var tree_scene: PackedScene
@export var gold_scene: PackedScene
@export var sheep_scene: PackedScene

var _press_pending := false
var _press_position := Vector2.ZERO
var _tool_cursors := {}  # tipo de recurso -> Image
var _active_cursor := ""  # recurso sob o mouse ("" = cursor padrão)

@onready var _world: World = $World
@onready var _camera: GameCamera = $Camera
@onready var _build_manager: BuildManager = $BuildManager
@onready var _entities: Node2D = $Entities
@onready var _hud: Hud = $Hud


func _ready() -> void:
	GameState.reset()
	for type in TOOL_CURSOR_TEXTURES:
		var image: Image = TOOL_CURSOR_TEXTURES[type].get_image()
		image.resize(TOOL_CURSOR_SIZE, TOOL_CURSOR_SIZE, Image.INTERPOLATE_NEAREST)
		_tool_cursors[type] = image
	_build_manager.building_completed.connect(_on_building_completed)
	_camera.set_world_limits(_world.get_world_rect())

	# Casa inicial no centro do mapa (a contagem dos 2 aldeões iniciais vem do GameState.reset()).
	var start_cell := _world.get_center_cell() - house_data.footprint / 2
	_build_manager.place(house_data, start_cell)
	var gold_cells := _spawn_gold()
	var flock_centers := _spawn_flocks(gold_cells)
	_spawn_trees(gold_cells, flock_centers)
	_camera.position = _world.cell_to_world(_world.get_center_cell())
	_camera.reset_smoothing()

	_hud.build_requested.connect(_build_manager.start_placing)
	_build_manager.placement_failed.connect(_hud.show_message)
	_build_manager.placing_changed.connect(_hud.set_placing)
	_build_manager.placing_changed.connect(func(is_placing: bool): _camera.left_drag_enabled = not is_placing)


func _process(_delta: float) -> void:
	_update_cursor()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		_toggle_fullscreen()
	elif event.is_action_pressed("build_house"):
		_build_manager.start_placing(house_data)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_left_click(event)
	elif OS.is_debug_build() and event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		# Atalho de teste para ganhar recursos sem coletar.
		for type in GameState.resources:
			GameState.add_resource(type, 50)


## Troca o cursor pela ferramenta certa quando o mouse está sobre um recurso livre.
## Roda todo frame (e não só ao mover o mouse) porque a câmera pode se mover sob um mouse parado.
func _update_cursor() -> void:
	var hovered := ""
	# Não muda o cursor durante a construção nem quando o mouse está sobre a interface.
	if not _build_manager.is_placing() and get_viewport().gui_get_hovered_control() == null:
		var source := _find_gatherable_at(get_global_mouse_position())
		if source != null and source.can_be_targeted() and source.worker == null:
			hovered = source.resource_type
	if hovered == _active_cursor:
		return
	_active_cursor = hovered
	# Imagem nula volta ao cursor padrão do sistema. O ponto ativo fica no centro da ferramenta.
	Input.set_custom_mouse_cursor(
		_tool_cursors.get(hovered),
		Input.CURSOR_ARROW,
		Vector2(TOOL_CURSOR_SIZE, TOOL_CURSOR_SIZE) / 2.0
	)


func _toggle_fullscreen() -> void:
	var is_fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_WINDOWED if is_fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN
	)


## Distingue clique de arrasto: o botão esquerdo também move a câmera, então só conta como
## clique se soltar perto de onde apertou. O BuildManager "consome" os cliques de construção,
## então o press deles nunca chega aqui.
func _handle_left_click(event: InputEventMouseButton) -> void:
	if event.pressed:
		_press_pending = true
		_press_position = event.position
	elif _press_pending:
		_press_pending = false
		if event.position.distance_to(_press_position) <= CLICK_DRAG_THRESHOLD:
			_on_world_clicked(get_global_mouse_position())


func _on_world_clicked(world_point: Vector2) -> void:
	var source := _find_gatherable_at(world_point)
	if source != null and source.can_be_targeted():
		_assign_gatherer(source)


## Pergunta à física o que está sob o ponto, olhando só a camada `collectibles`.
func _find_gatherable_at(world_point: Vector2) -> Gatherable:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = world_point
	query.collision_mask = PhysicsLayers.COLLECTIBLES
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var best: Gatherable = null
	# Sprites vizinhos se sobrepõem: vale o que está mais à frente (maior y), como no desenho.
	for hit in get_world_2d().direct_space_state.intersect_point(query, 8):
		var source := hit.collider as Gatherable
		# Um recurso removido ainda existe até o fim do frame; não conta como alvo.
		if source != null and not source.is_queued_for_deletion() \
				and (best == null or source.position.y > best.position.y):
			best = source
	return best


## Escolhe o aldeão disponível com o caminho mais curto até o recurso e manda trabalhar nele.
func _assign_gatherer(source: Gatherable) -> void:
	if source.worker != null:
		_hud.show_message("Já tem um aldeão trabalhando aí.")
		return
	if GameState.available_villagers() <= 0:
		_hud.show_message("Nenhum aldeão disponível.")
		return

	var task := Pawn.find_nearest_available(get_tree().get_nodes_in_group(PhysicsLayers.GROUP_UNITS),
			func(pawn: Pawn): return _world.find_path_to_adjacent(pawn.position, source.cell))
	if task.is_empty():
		_hud.show_message("Nenhum aldeão consegue chegar até lá.")
		return
	task.pawn.assign_gather(source, task.path)


## Cria os veios de ouro e devolve as células ocupadas.
func _spawn_gold() -> Array[Vector2i]:
	var occupied: Array[Vector2i] = []
	for center in _pick_group_centers(GOLD_VEIN_COUNT, GOLD_CLEARING_RADIUS, GOLD_VEIN_SPACING, []):
		for cell in _grow_vein(center, randi_range(GOLD_PER_VEIN.x, GOLD_PER_VEIN.y)):
			_spawn_gold_ore(cell)
			occupied.append(cell)
	return occupied


## Cria os rebanhos, longe dos veios de ouro, e devolve o centro de cada um.
func _spawn_flocks(gold_cells: Array[Vector2i]) -> Array[Vector2i]:
	var centers := _pick_group_centers(FLOCK_COUNT, FLOCK_CLEARING_RADIUS, FLOCK_SPACING, gold_cells)
	for center in centers:
		var flock := Flock.new()
		flock.setup(_world, center, randi_range(SHEEP_PER_FLOCK.x, SHEEP_PER_FLOCK.y), _spawn_sheep)
		add_child(flock)
		flock.populate()
	return centers


## Sorteia até `count` células livres para centros de grupos: a pelo menos `house_distance` da
## casa inicial, a `spacing` umas das outras e longe das células em `avoid`.
func _pick_group_centers(count: int, house_distance: float, spacing: float,
		avoid: Array[Vector2i]) -> Array[Vector2i]:
	var house := _world.get_center_cell()
	var candidates := _free_cells(func(cell: Vector2i):
		return Vector2(cell - house).length() >= house_distance and _is_away_from_border(cell) \
				and not avoid.any(func(other: Vector2i): return Vector2(cell - other).length() < spacing / 2.0))
	candidates.shuffle()
	var centers: Array[Vector2i] = []
	for cell in candidates:
		if centers.size() >= count:
			break
		if not centers.any(func(other: Vector2i): return Vector2(cell - other).length() < spacing):
			centers.append(cell)
	return centers


## Sorteia as células de um veio: cada minério novo encosta (inclusive na diagonal) num já
## escolhido, sem deixar nenhum sem um lado livre para o aldeão chegar.
func _grow_vein(start: Vector2i, size: int) -> Array[Vector2i]:
	var vein: Array[Vector2i] = [start]
	for attempt in 100:
		if vein.size() >= size:
			break
		var step := Vector2i(randi_range(-1, 1), randi_range(-1, 1))
		var cell: Vector2i = vein.pick_random() + step
		if cell in vein or not _world.is_cell_free(cell) or not _is_away_from_border(cell):
			continue
		var grown: Array[Vector2i] = vein.duplicate()
		grown.append(cell)
		if grown.all(func(stone: Vector2i): return _has_open_side(stone, grown)):
			vein = grown
	return vein


func _has_open_side(cell: Vector2i, vein: Array[Vector2i]) -> bool:
	return [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT].any(
			func(side: Vector2i): return not (cell + side) in vein and _world.is_cell_free(cell + side))


func _is_away_from_border(cell: Vector2i) -> bool:
	return cell.x >= 3 and cell.y >= 3 and cell.x < World.MAP_SIZE.x - 3 and cell.y < World.MAP_SIZE.y - 3


## Células livres do mapa que passam em `filter`.
func _free_cells(filter: Callable) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in World.MAP_SIZE.x:
		for y in World.MAP_SIZE.y:
			var cell := Vector2i(x, y)
			if _world.is_cell_free(cell) and filter.call(cell):
				cells.append(cell)
	return cells


func _spawn_sheep(cell: Vector2i) -> Sheep:
	var sheep: Sheep = sheep_scene.instantiate()
	sheep.setup(_world)
	_add_resource_node(sheep, cell)
	return sheep


func _spawn_gold_ore(cell: Vector2i) -> void:
	var ore: GoldOre = gold_scene.instantiate()
	ore.data = GOLD_TYPES.pick_random()
	_add_resource_node(ore, cell)


## Espalha as árvores por células livres sorteadas, fora da clareira em volta da casa inicial
## sem encostar nos veios de ouro nem invadir os pastos.
func _spawn_trees(gold_cells: Array[Vector2i], flock_centers: Array[Vector2i]) -> void:
	var house := _world.get_center_cell()
	var candidates := _free_cells(func(cell: Vector2i):
		return Vector2(cell - house).length() >= START_CLEARING_RADIUS \
				and not gold_cells.any(func(gold: Vector2i): return Vector2(cell - gold).length() <= GOLD_TREE_MARGIN) \
				and not flock_centers.any(func(flock: Vector2i): return Vector2(cell - flock).length() <= PASTURE_TREE_MARGIN))
	candidates.shuffle()
	for i in mini(TREE_COUNT, candidates.size()):
		_spawn_tree(candidates[i])


func _spawn_tree(cell: Vector2i) -> void:
	var tree: WoodTree = tree_scene.instantiate()
	tree.data = TREE_TYPES.pick_random()
	_add_resource_node(tree, cell)


## Põe um recurso no mapa, ocupando a célula (animais não bloqueiam o caminho).
func _add_resource_node(source: Gatherable, cell: Vector2i) -> void:
	source.cell = cell
	# Base um pouco abaixo do centro da célula.
	source.position = _world.cell_to_center(cell) + Vector2(0, 20)
	source.removed.connect(_on_resource_removed)
	if source.blocks_movement():
		_world.block_cell(cell)
	else:
		_world.occupy_cell(cell)
	_entities.add_child(source)


## Recurso removido (toco arrancado, ouro ou carne esgotados): a célula volta a ficar livre.
func _on_resource_removed(source: Gatherable) -> void:
	if source.blocks_movement():
		_world.unblock_cell(source.cell)
	else:
		_world.release_cell(source.cell)


## Cada casa gera seus aldeões, parados em frente à porta (o lado depende da orientação).
func _on_building_completed(building: Building) -> void:
	var size := Vector2(building.data.footprint * World.TILE_SIZE)
	var center := building.position + Vector2(size.x / 2.0, -size.y / 2.0)
	var direction := Vector2(building.data.door_directions[building.variant])
	# Ponto na borda da área ocupada, saindo da porta, mais uma folga.
	# A porta pode dar numa árvore ou em outra casa: nesse caso usa o espaço livre mais próximo.
	var door := _world.nearest_free_point(center + direction * (size / 2.0 + Vector2(36, 36)))
	var along_wall := Vector2(-direction.y, direction.x)
	for i in GameState.VILLAGERS_PER_HOUSE:
		var pawn: Pawn = pawn_scene.instantiate()
		pawn.position = _world.nearest_free_point(door + along_wall * (i - 0.5) * 56)
		pawn.setup(door, _world)
		_entities.add_child(pawn)
