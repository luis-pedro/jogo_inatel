extends Node2D
## Cena principal: monta o mapa, a câmera, a construção e a interface.

@export var house_data: BuildingData
@export var pawn_scene: PackedScene

@onready var _world: World = $World
@onready var _camera: GameCamera = $Camera
@onready var _build_manager: BuildManager = $BuildManager
@onready var _entities: Node2D = $Entities
@onready var _hud: Hud = $Hud


func _ready() -> void:
	GameState.reset()
	_build_manager.building_placed.connect(_on_building_placed)
	_camera.set_world_limits(_world.get_world_rect())

	# Casa inicial no centro do mapa (a contagem dos 2 aldeões iniciais vem do GameState.reset()).
	var start_cell := _world.get_center_cell() - house_data.footprint / 2
	_build_manager.place(house_data, start_cell)
	_camera.position = _world.cell_to_world(_world.get_center_cell())
	_camera.reset_smoothing()

	_hud.build_requested.connect(_build_manager.start_placing)
	_build_manager.placing_changed.connect(_hud.set_placing)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("build_house"):
		_build_manager.start_placing(house_data)
	elif OS.is_debug_build() and event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		# Atalho de teste enquanto não existe coleta de recursos.
		for type in GameState.resources:
			GameState.add_resource(type, 50)


## Cada casa gera seus aldeões, parados em frente à porta.
func _on_building_placed(building: Building) -> void:
	var door := building.position + Vector2(building.data.footprint.x * World.TILE_SIZE / 2.0, 36)
	for i in GameState.VILLAGERS_PER_HOUSE:
		var pawn: Pawn = pawn_scene.instantiate()
		pawn.position = door + Vector2((i - 0.5) * 56, 0)
		_entities.add_child(pawn)
