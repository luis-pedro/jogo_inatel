class_name Hud
extends CanvasLayer
## Interface: recursos, aldeões (disponíveis/total), mensagens e botão de construir casa.

signal build_requested(data: BuildingData)

const MESSAGE_SECONDS := 2.0

@export var house_data: BuildingData

var _message_tween: Tween

@onready var _resources: Label = %ResourcesLabel
@onready var _population: Label = %PopulationLabel
@onready var _build_button: Button = %BuildHouseButton
@onready var _hint: Label = %HintLabel
@onready var _message: Label = %MessageLabel


func _ready() -> void:
	_build_button.pressed.connect(func(): build_requested.emit(house_data))
	GameState.resources_changed.connect(_update_resources)
	GameState.villagers_changed.connect(_update_villagers)
	_build_button.text = "Construir %s (B)  —  %s" % [house_data.display_name, _format_cost(house_data.cost)]
	_update_resources(GameState.resources)
	_update_villagers()
	_message.modulate.a = 0.0
	set_placing(false)


func set_placing(is_placing: bool) -> void:
	_hint.visible = is_placing


## Mostra um aviso rápido na tela, que some sozinho.
func show_message(text: String) -> void:
	_message.text = text
	if _message_tween:
		_message_tween.kill()
	_message.modulate.a = 1.0
	_message_tween = create_tween()
	_message_tween.tween_interval(MESSAGE_SECONDS)
	_message_tween.tween_property(_message, "modulate:a", 0.0, 0.5)


func _update_resources(resources: Dictionary) -> void:
	_resources.text = "Comida: %d    Ouro: %d    Madeira: %d" % [
		resources.get("food", 0), resources.get("gold", 0), resources.get("wood", 0)
	]
	_build_button.disabled = not GameState.can_afford(house_data.cost)


func _update_villagers() -> void:
	_population.text = "Aldeões: %d disponíveis / %d no total" % [
		GameState.available_villagers(), GameState.population
	]


func _format_cost(cost: Dictionary) -> String:
	const NAMES := {"food": "comida", "gold": "ouro", "wood": "madeira"}
	var parts: PackedStringArray = []
	for type in cost:
		parts.append("%d %s" % [cost[type], NAMES.get(type, type)])
	return ", ".join(parts)
