class_name BuildManager
extends Node2D
## Controla a construção: fantasma que segue o mouse na grade, validação e criação do prédio.

signal placing_changed(is_placing: bool)

const BUILDING_SCENE := preload("res://scenes/buildings/building.tscn")
const VALID_COLOR := Color(0.6, 1.0, 0.6, 0.7)
const INVALID_COLOR := Color(1.0, 0.4, 0.4, 0.7)

@export var world: World

var _occupied: Dictionary = {}  # Vector2i -> true
var _current: BuildingData
var _ghost: Building

@onready var _buildings: Node2D = $Buildings


func _process(_delta: float) -> void:
	if _ghost == null:
		return
	var cell := _cell_under_mouse(_current)
	_ghost.setup(_current, cell, World.TILE_SIZE)
	_ghost.modulate = VALID_COLOR if _can_place(_current, cell) else INVALID_COLOR


func _unhandled_input(event: InputEvent) -> void:
	if _ghost == null:
		return
	if event.is_action_pressed("cancel_build"):
		stop_placing()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if try_place(_current, _cell_under_mouse(_current)) \
					and not GameState.can_afford(_current.cost):
				# Sem recursos para outra, sai do modo de construção.
				stop_placing()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			stop_placing()


func start_placing(data: BuildingData) -> void:
	stop_placing()
	_current = data
	_ghost = BUILDING_SCENE.instantiate()
	_ghost.setup(data, _cell_under_mouse(data), World.TILE_SIZE)
	add_child(_ghost)
	placing_changed.emit(true)


func stop_placing() -> void:
	if _ghost == null:
		return
	_ghost.queue_free()
	_ghost = null
	_current = null
	placing_changed.emit(false)


## Constrói pagando o custo. Retorna se a construção foi feita.
func try_place(data: BuildingData, cell: Vector2i) -> bool:
	if not _can_place(data, cell) or not GameState.spend(data.cost):
		return false
	place(data, cell)
	GameState.add_house()
	return true


## Põe o prédio no mapa sem custo nem validação (ex.: casa inicial).
func place(data: BuildingData, cell: Vector2i) -> Building:
	var building: Building = BUILDING_SCENE.instantiate()
	building.setup(data, cell, World.TILE_SIZE)
	_buildings.add_child(building)
	for covered in _footprint_cells(data, cell):
		_occupied[covered] = true
	return building


func _can_place(data: BuildingData, cell: Vector2i) -> bool:
	if not GameState.can_afford(data.cost):
		return false
	for covered in _footprint_cells(data, cell):
		if not world.is_buildable(covered) or _occupied.has(covered):
			return false
	return true


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
