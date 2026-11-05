class_name Pawn
extends Node2D
## Aldeão. Sem tarefa, passeia pela vila (idle ⇄ andar). Com a tarefa de cortar uma árvore:
## vai até ela, corta até encher a mochila (ou a árvore acabar), leva a madeira até a porta da
## casa, entrega (só aí o estoque sobe) e volta para a árvore enquanto ainda houver madeira.

enum State { IDLE, WALK, TO_TREE, WAIT_GROWTH, CHOP, UPROOT, TO_HOME }
## O que o jogador mandou fazer: cortar a árvore ou arrancar o toco.
enum Goal { CHOP, UPROOT }

const IDLE_TEXTURE := preload("res://assets/Units/Blue Units/Pawn/Pawn_Idle.png")
const RUN_TEXTURE := preload("res://assets/Units/Blue Units/Pawn/Pawn_Run.png")
const RUN_AXE_TEXTURE := preload("res://assets/Units/Blue Units/Pawn/Pawn_Run Axe.png")
const RUN_WOOD_TEXTURE := preload("res://assets/Units/Blue Units/Pawn/Pawn_Run Wood.png")
const CHOP_TEXTURE := preload("res://assets/Units/Blue Units/Pawn/Pawn_Interact Axe.png")
const FRAME_SIZE := Vector2i(192, 192)
## Altura (em px, a partir do topo do frame) onde ficam os pés do personagem.
const FEET_Y := 127

const WALK_SPEED := 55.0
const WORK_SPEED := 90.0
const WANDER_RADIUS := 220.0
const IDLE_TIME := Vector2(1.5, 4.0)  # segundos (mín., máx.)
const MIN_WALK_DISTANCE := 60.0
const PATH_CHECK_STEP := 16.0
const TARGET_ATTEMPTS := 8
## Madeira ganha a cada machadada completa (um ciclo da animação de corte).
const WOOD_PER_CHOP := 2
## Quanta madeira cabe na mochila antes de ter que levar para casa. Com 13, uma árvore grande
## (14 a 25 de madeira) dá 2 viagens e uma pequena (5 a 12) dá 1.
const BACKPACK_CAPACITY := 13
## Machadadas (ciclos da animação) para arrancar um toco.
const UPROOT_SWINGS := 3

var _state := State.IDLE
var _timer := 0.0
var _target := Vector2.ZERO
## Porta da casa do aldeão: centro do passeio e ponto de entrega.
var _home := Vector2.ZERO
var _world: World

var _tree: WoodTree
var _goal := Goal.CHOP
var _uproot_swings := 0
var _path := PackedVector2Array()
var _path_index := 0
var _carried_wood := 0

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


## Define a porta da casa (onde passeia e entrega recursos) e o mapa onde anda.
## Chamar antes de entrar na árvore da cena.
func setup(home: Vector2, world: World) -> void:
	_home = home
	_world = world


func _ready() -> void:
	add_to_group(PhysicsLayers.GROUP_UNITS)
	_sprite.sprite_frames = _build_frames()
	_sprite.animation_looped.connect(_on_animation_looped)
	# Origem do nó nos pés, para o y_sort ordenar corretamente.
	_sprite.offset = Vector2(0, FRAME_SIZE.y / 2.0 - FEET_Y)
	_start_idle()
	# Começa em um frame (e com um tempo de espera) aleatório para os aldeões não ficarem sincronizados.
	_sprite.frame = randi() % _sprite.sprite_frames.get_frame_count("idle")
	_timer = randf_range(0.0, IDLE_TIME.y)


## Livre para receber uma tarefa (está parado ou passeando).
func is_available() -> bool:
	return _state == State.IDLE or _state == State.WALK


## Manda o aldeão trabalhar em `tree` seguindo `path` (pontos do mundo): cortar, se for árvore,
## ou arrancar, se for toco. Reserva ele em GameState e reserva a árvore (que para de crescer).
func assign_gather(tree: WoodTree, path: PackedVector2Array) -> void:
	if not is_available() or not GameState.reserve_villager():
		return
	_tree = tree
	_goal = Goal.UPROOT if tree.is_stump() else Goal.CHOP
	_tree.worker = self  # reservada durante todas as viagens; um toco reservado não cresce
	_begin_path(State.TO_TREE, path, "run_axe")


func _physics_process(delta: float) -> void:
	match _state:
		State.IDLE:
			_timer -= delta
			if _timer <= 0.0:
				_try_start_walk()
		State.WALK:
			if _step_towards(_target, delta, WALK_SPEED):
				_start_idle()
		State.TO_TREE, State.TO_HOME:
			_follow_path(delta)


func _begin_path(state: State, path: PackedVector2Array, animation: String) -> void:
	_state = state
	_path = path
	_path_index = 0
	_sprite.play(animation)
	if _path.is_empty():
		_on_path_finished()


func _follow_path(delta: float) -> void:
	var waypoint := _path[_path_index]
	if absf(waypoint.x - position.x) > 1.0:
		_sprite.flip_h = waypoint.x < position.x
	if _step_towards(waypoint, delta, WORK_SPEED):
		_path_index += 1
		if _path_index >= _path.size():
			_on_path_finished()


func _on_path_finished() -> void:
	if _state == State.TO_TREE:
		_arrive_at_tree()
	else:
		_deliver_wood()


func _arrive_at_tree() -> void:
	_sprite.flip_h = _tree.position.x < position.x
	if _tree.stage == WoodTree.Stage.SAPLING:
		# A muda ainda está crescendo: espera ela ficar adulta e só então decide o que fazer.
		_state = State.WAIT_GROWTH
		_sprite.play("idle")
		_tree.regrown.connect(_arrive_at_tree, CONNECT_ONE_SHOT)
	elif _tree.is_grown():
		# Árvore adulta: corta primeiro, mesmo que a ordem tenha sido para o toco. Com a pausa do
		# crescimento isso não deveria acontecer, mas assim o aldeão nunca fica "perdido".
		_state = State.CHOP
		_sprite.play("chop")
	elif _goal == Goal.UPROOT and _tree.is_stump():
		_state = State.UPROOT
		_uproot_swings = 0
		_sprite.play("chop")
	else:
		_finish_task()


## Chamado a cada ciclo completo de uma animação em loop; no corte, cada ciclo é uma machadada.
func _on_animation_looped() -> void:
	match _state:
		State.CHOP:
			_carried_wood += _tree.take_wood(mini(WOOD_PER_CHOP, BACKPACK_CAPACITY - _carried_wood))
			if _carried_wood >= BACKPACK_CAPACITY or _tree.is_depleted():
				_go_home()
		State.UPROOT:
			_uproot_swings += 1
			if _uproot_swings >= UPROOT_SWINGS:
				_finish_uproot()


func _finish_uproot() -> void:
	_carried_wood += _tree.uproot()
	# A árvore sai do jogo no fim do frame: daqui em diante a referência não pode mais ser usada.
	_tree = null
	_go_home()


func _go_home() -> void:
	var path := _world.find_path(position, _home)
	if path.is_empty():
		# Sem caminho até a porta (ex.: cercada por construções): entrega aqui mesmo,
		# para a madeira não se perder nem o aldeão ficar preso na tarefa.
		_deliver_wood()
		return
	_begin_path(State.TO_HOME, path, "run_wood")


func _deliver_wood() -> void:
	if _carried_wood > 0:
		GameState.add_resource("wood", _carried_wood)
		_carried_wood = 0
	# Volta para a árvore se ainda há trabalho nela e o caminho continua existindo.
	if _should_return_to_tree():
		var path := _world.find_path_to_adjacent(position, _tree.cell)
		if not path.is_empty():
			_begin_path(State.TO_TREE, path, "run_axe")
			return
	_finish_task()


## Ainda há o que fazer na árvore: madeira para cortar ou, se a ordem era arrancar, um toco.
func _should_return_to_tree() -> bool:
	if _tree == null or not is_instance_valid(_tree):
		return false
	return _tree.is_grown() or (_goal == Goal.UPROOT and _tree.is_stump())


func _finish_task() -> void:
	if _tree != null and is_instance_valid(_tree):
		_tree.worker = null  # libera a árvore (e o toco volta a contar o crescimento)
	_tree = null
	_goal = Goal.CHOP
	GameState.release_villager()
	_start_idle()


## Anda um passo em direção a `point`. Retorna true ao chegar.
func _step_towards(point: Vector2, delta: float, speed: float) -> bool:
	var to_point := point - position
	var step := speed * delta
	if to_point.length() <= step:
		position = point
		return true
	position += to_point.normalized() * step
	return false


func _start_idle() -> void:
	_state = State.IDLE
	_timer = randf_range(IDLE_TIME.x, IDLE_TIME.y)
	_sprite.play("idle")


func _try_start_walk() -> void:
	for i in TARGET_ATTEMPTS:
		var candidate := _home + Vector2.from_angle(randf() * TAU) * randf_range(MIN_WALK_DISTANCE, WANDER_RADIUS)
		if _is_path_clear(position, candidate):
			_target = candidate
			_state = State.WALK
			# A arte olha para a direita; espelha quando vai para a esquerda.
			_sprite.flip_h = _target.x < position.x
			_sprite.play("run")
			return
	# Nenhum destino bom: descansa mais um pouco e tenta de novo.
	_start_idle()


## Confere o destino e pontos intermediários, para não atravessar casas nem sair da ilha.
func _is_path_clear(from: Vector2, to: Vector2) -> bool:
	if not _world.is_point_walkable(to):
		return false
	# Se o aldeão já está num lugar inválido (ex.: construíram em cima dele), só o destino importa.
	if not _world.is_point_walkable(from):
		return true
	var steps := int(from.distance_to(to) / PATH_CHECK_STEP)
	for i in range(1, steps):
		if not _world.is_point_walkable(from.lerp(to, float(i) / steps)):
			return false
	return true


func _build_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	SpriteSheets.add_animation(frames, "idle", IDLE_TEXTURE, FRAME_SIZE, 8.0)
	SpriteSheets.add_animation(frames, "run", RUN_TEXTURE, FRAME_SIZE, 10.0)
	SpriteSheets.add_animation(frames, "run_axe", RUN_AXE_TEXTURE, FRAME_SIZE, 10.0)
	SpriteSheets.add_animation(frames, "run_wood", RUN_WOOD_TEXTURE, FRAME_SIZE, 10.0)
	SpriteSheets.add_animation(frames, "chop", CHOP_TEXTURE, FRAME_SIZE, 10.0)
	return frames
