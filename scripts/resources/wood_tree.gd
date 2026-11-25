class_name WoodTree
extends Area2D
## Árvore que os aldeões cortam para ganhar madeira. Ciclo de vida:
##   GROWN (árvore) --corte--> STUMP (toco) --tempo--> SAPLING (muda crescendo) --> GROWN
## Um aldeão também pode arrancar o toco (`uproot`): a árvore some do jogo de vez e libera a célula.
## É uma Area2D na camada `collectibles` só para o clique do jogador achá-la.

## Terminou a madeira e virou toco.
signal depleted
## Voltou a ser árvore.
signal regrown
## Foi arrancada e vai ser removida da cena; quem bloqueou a célula deve liberá-la.
signal removed(tree: WoodTree)

enum Stage { GROWN, STUMP, SAPLING, REMOVED }

## Tipo usado quando nenhum é definido antes de a árvore entrar na cena.
const DEFAULT_DATA := preload("res://data/trees/tree1.tres")
const SWAY_FPS := 6.0

## Duração da animação em que a muda cresce até o tamanho final.
const GROW_ANIMATION_SECONDS := 1.5
const SAPLING_SCALE := 0.3

## Tipo da árvore (sprites do pé de árvore e do toco). Definir antes de entrar na cena.
@export var data: TreeData
## Madeira que ainda resta na árvore (sorteada em `roll_wood_amount()`).
var wood := 0
var stage := Stage.GROWN
## Célula do mapa que a árvore ocupa.
var cell: Vector2i
## Aldeão que reservou esta árvore/toco (só um por vez). Tipado como Node2D de propósito:
## usar `Pawn` aqui criaria uma dependência circular com pawn.gd, que usa `WoodTree`.
## Enquanto houver um aldeão reservado, a contagem para o toco voltar a crescer fica PAUSADA.
var worker: Node2D

var _regrow_left := 0.0
var _click_shape := RectangleShape2D.new()

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	if data == null:
		data = DEFAULT_DATA
	wood = roll_wood_amount()
	collision_mask = 0
	_set_targetable(true)
	# Só o toco precisa do _process (contagem de crescimento); as árvores adultas não gastam nada.
	set_process(false)

	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	SpriteSheets.add_animation(frames, "sway", data.tree_texture, data.tree_frame_size, SWAY_FPS)
	SpriteSheets.add_animation(frames, "stump", data.stump_texture, data.stump_frame_size, 1.0)
	_sprite.sprite_frames = frames
	# Cada instância precisa do seu próprio shape: o da cena é compartilhado entre todas as árvores.
	_collision.shape = _click_shape
	_show_tree()


func _process(delta: float) -> void:
	# Com um aldeão a caminho do toco (ou trabalhando nele) o tempo de crescimento congela.
	if stage != Stage.STUMP or worker != null:
		return
	_regrow_left -= delta
	if _regrow_left <= 0.0:
		_start_growing()


func is_grown() -> bool:
	return stage == Stage.GROWN


func is_stump() -> bool:
	return stage == Stage.STUMP


func is_depleted() -> bool:
	return wood <= 0


## Pode receber uma ordem do jogador: árvore adulta (cortar) ou toco (arrancar).
## A muda ainda crescendo e a árvore já removida não podem.
func can_be_targeted() -> bool:
	return stage == Stage.GROWN or stage == Stage.STUMP


## Retira até `amount` de madeira e devolve quanto foi retirado.
func take_wood(amount: int) -> int:
	var taken := mini(amount, wood)
	wood -= taken
	if is_depleted() and stage == Stage.GROWN:
		_become_stump()
	return taken


## Arranca o toco: a árvore some do jogo (a célula volta a ficar livre) e devolve a madeira que
## o toco dava. Só funciona num toco; em qualquer outro estágio devolve 0 e não faz nada.
func uproot() -> int:
	if stage != Stage.STUMP:
		return 0
	stage = Stage.REMOVED
	set_process(false)
	_set_targetable(false)
	removed.emit(self)
	# queue_free (e não free): a remoção acontece no fim do frame, com segurança dentro de sinais.
	# Ao sair da cena, o nó leva junto sprite, colisão, grupo e tween (nada fica rodando).
	queue_free()
	return randi_range(data.stump_wood_min, data.stump_wood_max)


## Sorteia quanta madeira a árvore dá, dentro da faixa do seu tipo. Árvores grandes dão mais
## que as pequenas, e a cada rebrota o valor muda.
func roll_wood_amount() -> int:
	return randi_range(data.wood_min, data.wood_max)


## Sorteia quanto tempo (em segundos) este toco leva para virar árvore de novo, dentro da faixa
## do seu tipo (grandes demoram mais). É chamada a cada vez que a árvore é cortada, então varia
## entre árvores e entre ciclos. Para outra regra (ex.: depender do terreno ou da estação),
## mude só esta função.
func roll_regrow_time() -> float:
	return randf_range(data.regrow_time_min, data.regrow_time_max)


func _become_stump() -> void:
	stage = Stage.STUMP
	_regrow_left = roll_regrow_time()
	set_process(true)
	_show_stump()
	depleted.emit()


func _start_growing() -> void:
	stage = Stage.SAPLING
	set_process(false)
	# Muda não é alvo: só volta a poder ser cortada depois de crescer.
	_set_targetable(false)
	wood = roll_wood_amount()
	_show_tree()
	_sprite.scale = Vector2.ONE * SAPLING_SCALE
	var tween := create_tween()
	tween.tween_property(_sprite, "scale", Vector2.ONE, GROW_ANIMATION_SECONDS) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_finish_growing)


func _finish_growing() -> void:
	stage = Stage.GROWN
	_set_targetable(true)
	regrown.emit()


## Mostra a árvore ou o toco. Os sprites têm tamanhos de frame e bases diferentes,
## então o deslocamento e a área clicável (o toco é bem menor) são refeitos a cada troca.
func _show_tree() -> void:
	# Origem do nó na base do tronco, para o y_sort ordenar corretamente.
	_sprite.offset = Vector2(0, data.tree_frame_size.y / 2.0 - data.tree_feet_y)
	_sprite.play("sway")
	_sprite.frame = randi() % _sprite.sprite_frames.get_frame_count("sway")
	_set_click_size(data.click_size)


func _show_stump() -> void:
	_sprite.offset = Vector2(0, data.stump_frame_size.y / 2.0 - data.stump_feet_y)
	_sprite.play("stump")
	_set_click_size(data.stump_click_size)


## Base da área clicável nos pés da árvore.
func _set_click_size(size: Vector2) -> void:
	_click_shape.size = size
	_collision.position = Vector2(0, -size.y / 2.0)


## Liga/desliga como alvo de ordens: grupo `collectibles` (busca) e camada de física (clique).
func _set_targetable(targetable: bool) -> void:
	if targetable:
		add_to_group(PhysicsLayers.GROUP_COLLECTIBLES)
	else:
		remove_from_group(PhysicsLayers.GROUP_COLLECTIBLES)
	# set_deferred: evita mudar o estado da física no meio de um callback.
	set_deferred("collision_layer", PhysicsLayers.COLLECTIBLES if targetable else 0)
