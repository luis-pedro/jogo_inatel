class_name WoodTree
extends Area2D
## Árvore que os aldeões cortam para ganhar madeira. Ao acabar a madeira vira um toco e, depois
## de um tempo (diferente a cada árvore), cresce de novo.
## É uma Area2D na camada `collectibles` só para o clique do jogador achá-la.

signal depleted
signal regrown

## Tipo usado quando nenhum é definido antes de a árvore entrar na cena.
const DEFAULT_DATA := preload("res://data/trees/tree1.tres")
const SWAY_FPS := 6.0

## Duração da animação em que a muda cresce até o tamanho final.
const GROW_ANIMATION_SECONDS := 1.5
const SAPLING_SCALE := 0.3
## Se um aldeão ainda está usando a árvore quando ela deveria crescer, tenta de novo depois.
const REGROW_RETRY_SECONDS := 5.0

## Tipo da árvore (sprites do pé de árvore e do toco). Definir antes de entrar na cena.
@export var data: TreeData
@export var wood := 12
## O toco leva um tempo sorteado entre estes dois valores (em segundos) para virar árvore de novo.
## Ajustável por árvore no Inspetor.
@export var regrow_time_min := 45.0
@export var regrow_time_max := 90.0

## Célula do mapa que a árvore ocupa.
var cell: Vector2i
## Aldeão que está cortando agora (só um por árvore). Tipado como Node2D de propósito:
## usar `Pawn` aqui criaria uma dependência circular com pawn.gd, que usa `WoodTree`.
var worker: Node2D

var _max_wood := 0

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	if data == null:
		data = DEFAULT_DATA
	_max_wood = wood
	collision_mask = 0
	_set_choppable(true)

	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	SpriteSheets.add_animation(frames, "sway", data.tree_texture, data.tree_frame_size, SWAY_FPS)
	SpriteSheets.add_animation(frames, "stump", data.stump_texture, data.stump_frame_size, 1.0)
	_sprite.sprite_frames = frames
	_setup_click_area()
	_show_tree()


## Cada instância precisa do seu próprio shape: o da cena é compartilhado entre todas as árvores.
func _setup_click_area() -> void:
	var shape := RectangleShape2D.new()
	shape.size = data.click_size
	var collision: CollisionShape2D = $CollisionShape2D
	collision.shape = shape
	# Base da área clicável nos pés da árvore.
	collision.position = Vector2(0, -data.click_size.y / 2.0)


## Mostra a árvore ou o toco. Os sprites têm tamanhos de frame e bases diferentes,
## então o deslocamento é refeito a cada troca.
func _show_tree() -> void:
	# Origem do nó na base do tronco, para o y_sort ordenar corretamente.
	_sprite.offset = Vector2(0, data.tree_frame_size.y / 2.0 - data.tree_feet_y)
	_sprite.play("sway")
	_sprite.frame = randi() % _sprite.sprite_frames.get_frame_count("sway")


func _show_stump() -> void:
	_sprite.offset = Vector2(0, data.stump_frame_size.y / 2.0 - data.stump_feet_y)
	_sprite.play("stump")


func is_depleted() -> bool:
	return wood <= 0


## Retira até `amount` de madeira e devolve quanto foi retirado.
func take_wood(amount: int) -> int:
	var taken := mini(amount, wood)
	wood -= taken
	if is_depleted():
		_become_stump()
	return taken


## Sorteia quanto tempo (em segundos) este toco leva para virar árvore de novo.
## É chamada a cada vez que a árvore é cortada, então varia entre árvores e entre ciclos.
## Para outra regra (ex.: depender do terreno ou da estação), mude só esta função.
func roll_regrow_time() -> float:
	return randf_range(regrow_time_min, regrow_time_max)


func _become_stump() -> void:
	_set_choppable(false)
	_show_stump()
	depleted.emit()
	_schedule_regrow(roll_regrow_time())


func _schedule_regrow(seconds: float) -> void:
	get_tree().create_timer(seconds).timeout.connect(_try_regrow)


func _try_regrow() -> void:
	if worker != null:
		_schedule_regrow(REGROW_RETRY_SECONDS)
		return
	wood = _max_wood
	_show_tree()
	# A muda nasce pequena e cresce até o tamanho normal; só pode ser cortada depois disso.
	_sprite.scale = Vector2.ONE * SAPLING_SCALE
	var tween := create_tween()
	tween.tween_property(_sprite, "scale", Vector2.ONE, GROW_ANIMATION_SECONDS) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		_set_choppable(true)
		regrown.emit()
	)


## Liga/desliga a árvore como alvo de corte: grupo `collectibles` (busca) e camada de física (clique).
func _set_choppable(choppable: bool) -> void:
	if choppable:
		add_to_group(PhysicsLayers.GROUP_COLLECTIBLES)
	else:
		remove_from_group(PhysicsLayers.GROUP_COLLECTIBLES)
	# set_deferred: evita mudar o estado da física no meio de um callback.
	set_deferred("collision_layer", PhysicsLayers.COLLECTIBLES if choppable else 0)
