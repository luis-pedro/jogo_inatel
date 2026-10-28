class_name Hud
extends CanvasLayer
## Interface: recursos, população e botão de construir casa.

signal build_requested(data: BuildingData)

@export var house_data: BuildingData

@onready var _resources: Label = %ResourcesLabel
@onready var _population: Label = %PopulationLabel
@onready var _build_button: Button = %BuildHouseButton
@onready var _hint: Label = %HintLabel


func _ready() -> void:
	_build_button.pressed.connect(func(): build_requested.emit(house_data))
	GameState.resources_changed.connect(_update_resources)
	GameState.population_changed.connect(_update_population)
	_build_button.text = "Construir %s (B)  —  %s" % [house_data.display_name, _format_cost(house_data.cost)]
	_update_resources(GameState.resources)
	_update_population(GameState.population)
	set_placing(false)


func set_placing(is_placing: bool) -> void:
	_hint.visible = is_placing


func _update_resources(resources: Dictionary) -> void:
	_resources.text = "Comida: %d    Ouro: %d    Madeira: %d" % [
		resources.get("food", 0), resources.get("gold", 0), resources.get("wood", 0)
	]
	_build_button.disabled = not GameState.can_afford(house_data.cost)


func _update_population(population: int) -> void:
	_population.text = "Aldeões: %d" % population


func _format_cost(cost: Dictionary) -> String:
	const NAMES := {"food": "comida", "gold": "ouro", "wood": "madeira"}
	var parts: PackedStringArray = []
	for type in cost:
		parts.append("%d %s" % [cost[type], NAMES.get(type, type)])
	return ", ".join(parts)
