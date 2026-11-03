class_name WoodTree
extends Area2D
## Árvore que os aldeões cortam para ganhar madeira. Ao acabar a madeira vira um toco.
## É uma Area2D na camada `collectibles` só para o clique do jogador achá-la.

signal depleted

const TREE_TEXTURE := preload("res://assets/Terrain/Resources/Wood/Trees/Tree1.png")
const STUMP_TEXTURE := preload("res://assets/Terrain/Resources/Wood/Trees/Stump 1.png")
const FRAME_SIZE := Vector2i(192, 256)
## Altura (em px, a partir do topo do frame) onde fica a base do tronco.
const FEET_Y := 228
const SWAY_FPS := 6.0

@export var wood := 12

## Célula do mapa que a árvore ocupa.
var cell: Vector2i
## Aldeão que está cortando agora (só um por árvore).
var worker: Pawn

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	add_to_group(PhysicsLayers.GROUP_COLLECTIBLES)
	collision_layer = PhysicsLayers.COLLECTIBLES
	collision_mask = 0

	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	SpriteSheets.add_animation(frames, "sway", TREE_TEXTURE, FRAME_SIZE, SWAY_FPS)
	SpriteSheets.add_animation(frames, "stump", STUMP_TEXTURE, FRAME_SIZE, 1.0)
	_sprite.sprite_frames = frames
	# Origem do nó na base do tronco, para o y_sort ordenar corretamente.
	_sprite.offset = Vector2(0, FRAME_SIZE.y / 2.0 - FEET_Y)
	_sprite.play("sway")
	_sprite.frame = randi() % frames.get_frame_count("sway")


func is_depleted() -> bool:
	return wood <= 0


## Retira até `amount` de madeira e devolve quanto foi retirado.
func take_wood(amount: int) -> int:
	var taken := mini(amount, wood)
	wood -= taken
	if is_depleted():
		_become_stump()
	return taken


func _become_stump() -> void:
	remove_from_group(PhysicsLayers.GROUP_COLLECTIBLES)
	# set_deferred: evita mudar o estado da física no meio de um callback.
	set_deferred("collision_layer", 0)
	_sprite.play("stump")
	depleted.emit()
