class_name BuildManager
extends Node2D
## Controla a construção: fantasma que segue o mouse na grade, validação e criação do prédio.

signal placing_changed(is_placing: bool)
## Prédio pronto (o inicial, na hora; os do jogador, quando a obra termina).
signal building_completed(building: Building)
## Clique de construção recusado; `reason` é a mensagem para o jogador.
signal placement_failed(reason: String)

const BUILDING_SCENE := preload("res://scenes/buildings/building.tscn")
const VALID_COLOR := Color(0.6, 1.0, 0.6, 0.7)
const INVALID_COLOR := Color(1.0, 0.4, 0.4, 0.7)

@export var world: World
## Nó (com y_sort) onde os prédios são criados, compartilhado com as unidades.
@export var buildings_root: Node2D
## Nó acima de tudo (sem y-sort) onde fica o fantasma de construção.
@export var overlay: Node2D

var _current: BuildingData
var _ghost: Building
var _variant := 0  # orientação escolhida com R


func _process(_delta: float) -> void:
	if _ghost == null:
		return
	var cell := _cell_under_mouse(_current)
	_ghost.setup(_current, cell, World.TILE_SIZE, _variant)
	_ghost.modulate = VALID_COLOR if _can_place(_current, cell) else INVALID_COLOR


func _unhandled_input(event: InputEvent) -> void:
	if _ghost == null:
		return
	if event.is_action_pressed("cancel_build"):
		stop_placing()
	elif event.is_action_pressed("rotate_building"):
		_variant = (_variant + 1) % _current.textures.size()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if try_place(_current, _cell_under_mouse(_current)) \
					and not GameState.can_afford(_current.cost):
				# Sem recursos para outra, sai do modo de construção.
				stop_placing()
			# Marca como tratado para o clique não virar outra ação (ex.: selecionar uma árvore).
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			stop_placing()
			get_viewport().set_input_as_handled()


func is_placing() -> bool:
	return _ghost != null


func start_placing(data: BuildingData) -> void:
	stop_placing()
	_current = data
	_ghost = BUILDING_SCENE.instantiate()
	_ghost.setup(data, _cell_under_mouse(data), World.TILE_SIZE, _variant)
	overlay.add_child(_ghost)
	placing_changed.emit(true)


func stop_placing() -> void:
	if _ghost == null:
		return
	_ghost.queue_free()
	_ghost = null
	_current = null
	placing_changed.emit(false)


## Marca a obra, paga o custo e manda um aldeão construir. Retorna se conseguiu.
func try_place(data: BuildingData, cell: Vector2i) -> bool:
	var problem := _placement_problem(data, cell)
	if not problem.is_empty():
		placement_failed.emit(problem)
		return false
	# Bloqueia antes de procurar o construtor: o caminho dele já tem que desviar da própria obra.
	_block_footprint(data, cell, true)
	var task := _find_builder(data, cell)
	if task.is_empty():
		_block_footprint(data, cell, false)
		placement_failed.emit("Nenhum aldeão consegue chegar até a obra.")
		return false
	GameState.spend(data.cost)
	var site := _create_building(data, cell, _variant)
	site.construction_finished.connect(_on_construction_finished)
	site.start_construction()
	task.pawn.assign_build(site, task.path)
	return true


## Põe um prédio já pronto no mapa, sem custo nem validação (ex.: casa inicial).
func place(data: BuildingData, cell: Vector2i, variant := 0) -> Building:
	_block_footprint(data, cell, true)
	var building := _create_building(data, cell, variant)
	building_completed.emit(building)
	return building


func _create_building(data: BuildingData, cell: Vector2i, variant: int) -> Building:
	var building: Building = BUILDING_SCENE.instantiate()
	building.setup(data, cell, World.TILE_SIZE, variant)
	# Só entra no grupo quando está no mapa (o fantasma também é um Building).
	building.add_to_group(PhysicsLayers.GROUP_BUILDINGS)
	buildings_root.add_child(building)
	return building


## Os aldeões da casa só nascem quando a obra termina.
func _on_construction_finished(building: Building) -> void:
	GameState.add_house()
	building_completed.emit(building)


## Procura o aldeão livre mais próximo. Prefere que ele trabalhe pela frente (onde aparece por cima
## da poeira da obra); pelos lados ou atrás, onde a casa o esconderia, só se não houver outro lugar.
func _find_builder(data: BuildingData, cell: Vector2i) -> Dictionary:
	var front: Array[Vector2i] = []
	var sides: Array[Vector2i] = []
	var back: Array[Vector2i] = []
	for x in data.footprint.x:
		front.append(cell + Vector2i(x, data.footprint.y))
		back.append(cell + Vector2i(x, -1))
	for y in data.footprint.y:
		sides.append(cell + Vector2i(-1, y))
		sides.append(cell + Vector2i(data.footprint.x, y))

	var units := get_tree().get_nodes_in_group(PhysicsLayers.GROUP_UNITS)
	for goals: Array[Vector2i] in [front, sides, back]:
		var task := Pawn.find_nearest_available(units,
				func(pawn: Pawn): return world.find_path_to_any(pawn.position, goals))
		if not task.is_empty():
			return task
	return {}


## Por que não dá para construir aqui ("" se dá).
func _placement_problem(data: BuildingData, cell: Vector2i) -> String:
	if not GameState.can_afford(data.cost):
		return "Recursos insuficientes."
	for covered in _footprint_cells(data, cell):
		if not world.is_cell_free(covered):
			return "Não dá para construir aí."
	if GameState.available_villagers() <= 0:
		return "Nenhum aldeão disponível para construir."
	return ""


func _can_place(data: BuildingData, cell: Vector2i) -> bool:
	return _placement_problem(data, cell).is_empty()


func _block_footprint(data: BuildingData, cell: Vector2i, blocked: bool) -> void:
	for covered in _footprint_cells(data, cell):
		if blocked:
			world.block_cell(covered)
		else:
			world.unblock_cell(covered)


func _footprint_cells(data: BuildingData, cell: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in data.footprint.x:
		for y in data.footprint.y:
			cells.append(cell + Vector2i(x, y))
	return cells


## Célula do canto superior esquerdo, com o prédio centralizado no cursor.
func _cell_under_mouse(data: BuildingData) -> Vector2i:
	var half_footprint := Vector2(data.footprint * World.TILE_SIZE) / 2.0
	var half_tile := Vector2(World.TILE_SIZE, World.TILE_SIZE) / 2.0
	# Somar meio tile faz o floor() de world_to_cell arredondar para a célula mais próxima.
	return world.world_to_cell(get_global_mouse_position() - half_footprint + half_tile)
