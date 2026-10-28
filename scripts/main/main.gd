extends Node2D
## Cena principal: monta o mapa, a câmera, a construção e a interface.

@export var house_data: BuildingData

@onready var _world: World = $World
@onready var _camera: GameCamera = $Camera
@onready var _build_manager: BuildManager = $BuildManager
@onready var _hud: Hud = $Hud


func _ready() -> void:
	GameState.reset()
	_camera.set_world_limits(_world.get_world_rect())

	# Casa inicial no centro do mapa (os 2 aldeões iniciais já vêm do GameState.reset()).
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
