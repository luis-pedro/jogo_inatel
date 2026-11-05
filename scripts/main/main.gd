extends Node2D
## Cena principal: monta o mapa, a câmera, a construção e a interface.

## Quanto o mouse pode se mover (em px) entre apertar e soltar e ainda contar como clique.
## Acima disso é um arrasto (da câmera).
const CLICK_DRAG_THRESHOLD := 8.0

## Cursor de machado mostrado sobre árvores que podem ser cortadas.
const AXE_CURSOR_TEXTURE := preload("res://assets/Terrain/Resources/Tools/Tool_02.png")
const AXE_CURSOR_SIZE := 80

## Tipos de árvore sorteados ao criar o cenário (cada um com seu toco).
const TREE_TYPES := [
	preload("res://data/trees/tree1.tres"),
	preload("res://data/trees/tree2.tres"),
	preload("res://data/trees/tree3.tres"),
	preload("res://data/trees/tree4.tres"),
]

## Árvores do cenário de teste (células do mapa).
const TEST_TREE_CELLS: Array[Vector2i] = [
	Vector2i(24, 4), Vector2i(26, 6), Vector2i(28, 5), Vector2i(27, 8), Vector2i(30, 7),
	Vector2i(29, 10), Vector2i(32, 9), Vector2i(31, 12), Vector2i(25, 11),
	Vector2i(7, 15), Vector2i(9, 17), Vector2i(6, 18), Vector2i(11, 19),
	Vector2i(8, 13), Vector2i(12, 16), Vector2i(34, 15), Vector2i(33, 18),
]

@export var house_data: BuildingData
@export var pawn_scene: PackedScene
@export var tree_scene: PackedScene

var _press_pending := false
var _press_position := Vector2.ZERO
var _axe_cursor: Image
var _axe_cursor_active := false

@onready var _world: World = $World
@onready var _camera: GameCamera = $Camera
@onready var _build_manager: BuildManager = $BuildManager
@onready var _entities: Node2D = $Entities
@onready var _hud: Hud = $Hud


func _ready() -> void:
	GameState.reset()
	_axe_cursor = AXE_CURSOR_TEXTURE.get_image()
	_axe_cursor.resize(AXE_CURSOR_SIZE, AXE_CURSOR_SIZE, Image.INTERPOLATE_NEAREST)
	_build_manager.building_placed.connect(_on_building_placed)
	_camera.set_world_limits(_world.get_world_rect())

	# Casa inicial no centro do mapa (a contagem dos 2 aldeões iniciais vem do GameState.reset()).
	var start_cell := _world.get_center_cell() - house_data.footprint / 2
	_build_manager.place(house_data, start_cell)
	_spawn_test_trees()
	_camera.position = _world.cell_to_world(_world.get_center_cell())
	_camera.reset_smoothing()

	_hud.build_requested.connect(_build_manager.start_placing)
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


## Troca o cursor por um machado quando o mouse está sobre uma árvore que dá para cortar.
## Roda todo frame (e não só ao mover o mouse) porque a câmera pode se mover sob um mouse parado.
func _update_cursor() -> void:
	var over_choppable := false
	# Não mostra o machado durante a construção nem quando o mouse está sobre a interface.
	if not _build_manager.is_placing() and get_viewport().gui_get_hovered_control() == null:
		var tree := _find_tree_at(get_global_mouse_position())
		over_choppable = tree != null and tree.worker == null
	if over_choppable == _axe_cursor_active:
		return
	_axe_cursor_active = over_choppable
	# Imagem nula volta ao cursor padrão do sistema. O ponto ativo fica no centro do machado.
	Input.set_custom_mouse_cursor(
		_axe_cursor if over_choppable else null,
		Input.CURSOR_ARROW,
		Vector2(AXE_CURSOR_SIZE, AXE_CURSOR_SIZE) / 2.0
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
	var tree := _find_tree_at(world_point)
	if tree != null:
		_assign_gatherer(tree)


## Pergunta à física o que está sob o ponto, olhando só a camada `collectibles`.
func _find_tree_at(world_point: Vector2) -> WoodTree:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = world_point
	query.collision_mask = PhysicsLayers.COLLECTIBLES
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hits := get_world_2d().direct_space_state.intersect_point(query, 1)
	return hits[0].collider as WoodTree if not hits.is_empty() else null


## Escolhe o aldeão disponível com o caminho mais curto até a árvore e manda cortar.
func _assign_gatherer(tree: WoodTree) -> void:
	if tree.worker != null:
		_hud.show_message("Essa árvore já está sendo cortada.")
		return
	if GameState.available_villagers() <= 0:
		_hud.show_message("Nenhum aldeão disponível.")
		return

	var best_pawn: Pawn
	var best_path := PackedVector2Array()
	for node in get_tree().get_nodes_in_group(PhysicsLayers.GROUP_UNITS):
		var pawn := node as Pawn
		if pawn == null or not pawn.is_available():
			continue
		var path := _world.find_path_to_adjacent(pawn.position, tree.cell)
		if path.is_empty():
			continue
		if best_pawn == null or path.size() < best_path.size():
			best_pawn = pawn
			best_path = path

	if best_pawn == null:
		_hud.show_message("Nenhum aldeão consegue chegar até a árvore.")
		return
	best_pawn.assign_gather(tree, best_path)


func _spawn_test_trees() -> void:
	for cell in TEST_TREE_CELLS:
		var tree: WoodTree = tree_scene.instantiate()
		tree.cell = cell
		tree.data = TREE_TYPES.pick_random()
		# Base do tronco um pouco abaixo do centro da célula.
		tree.position = _world.cell_to_center(cell) + Vector2(0, 20)
		_world.block_cell(cell)
		_entities.add_child(tree)


## Cada casa gera seus aldeões, parados em frente à porta (o lado depende da orientação).
func _on_building_placed(building: Building) -> void:
	var size := Vector2(building.data.footprint * World.TILE_SIZE)
	var center := building.position + Vector2(size.x / 2.0, -size.y / 2.0)
	var direction := Vector2(building.data.door_directions[building.variant])
	# Ponto na borda da área ocupada, saindo da porta, mais uma folga.
	var door := center + direction * (size / 2.0 + Vector2(36, 36))
	var along_wall := Vector2(-direction.y, direction.x)
	for i in GameState.VILLAGERS_PER_HOUSE:
		var pawn: Pawn = pawn_scene.instantiate()
		pawn.position = door + along_wall * (i - 0.5) * 56
		pawn.setup(door, _world)
		_entities.add_child(pawn)
