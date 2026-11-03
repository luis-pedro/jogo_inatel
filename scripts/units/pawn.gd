class_name Pawn
extends Node2D
## Aldeão. Sem tarefa, passeia pela vila (idle ⇄ andar). Pode receber a tarefa de cortar uma árvore:
## vai até ela, corta até acabar a madeira e volta a ficar disponível.

enum State { IDLE, WALK, TO_TREE, CHOP }

const IDLE_TEXTURE := preload("res://assets/Units/Blue Units/Pawn/Pawn_Idle.png")
const RUN_TEXTURE := preload("res://assets/Units/Blue Units/Pawn/Pawn_Run.png")
const RUN_AXE_TEXTURE := preload("res://assets/Units/Blue Units/Pawn/Pawn_Run Axe.png")
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

var _state := State.IDLE
var _timer := 0.0
var _target := Vector2.ZERO
var _home := Vector2.ZERO
var _is_walkable := func(_point: Vector2) -> bool: return true

var _tree: WoodTree
var _path := PackedVector2Array()
var _path_index := 0

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


## Define o ponto ao redor do qual o aldeão passeia e a regra de onde ele pode pisar.
## Chamar antes de entrar na árvore da cena.
func setup(home: Vector2, is_walkable: Callable) -> void:
	_home = home
	_is_walkable = is_walkable


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


## Manda o aldeão cortar `tree` seguindo `path` (pontos do mundo). Reserva ele em GameState.
func assign_gather(tree: WoodTree, path: PackedVector2Array) -> void:
	if not is_available() or not GameState.reserve_villager():
		return
	_tree = tree
	_tree.worker = self
	_path = path
	_path_index = 0
	_state = State.TO_TREE
	_sprite.play("run_axe")
	if _path.is_empty():
		_arrive_at_tree()


func _physics_process(delta: float) -> void:
	match _state:
		State.IDLE:
			_timer -= delta
			if _timer <= 0.0:
				_try_start_walk()
		State.WALK:
			if _step_towards(_target, delta, WALK_SPEED):
				_start_idle()
		State.TO_TREE:
			_follow_path(delta)


func _follow_path(delta: float) -> void:
	var waypoint := _path[_path_index]
	if absf(waypoint.x - position.x) > 1.0:
		_sprite.flip_h = waypoint.x < position.x
	if _step_towards(waypoint, delta, WORK_SPEED):
		_path_index += 1
		if _path_index >= _path.size():
			_arrive_at_tree()


func _arrive_at_tree() -> void:
	if _tree.is_depleted():
		_finish_task()
		return
	_state = State.CHOP
	_sprite.flip_h = _tree.position.x < position.x
	_sprite.play("chop")


## Chamado a cada ciclo completo de uma animação em loop; no corte, cada ciclo é uma machadada.
func _on_animation_looped() -> void:
	if _state != State.CHOP:
		return
	GameState.add_resource("wood", _tree.take_wood(WOOD_PER_CHOP))
	if _tree.is_depleted():
		_finish_task()


func _finish_task() -> void:
	_tree.worker = null
	_tree = null
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
	if not _is_walkable.call(to):
		return false
	# Se o aldeão já está num lugar inválido (ex.: construíram em cima dele), só o destino importa.
	if not _is_walkable.call(from):
		return true
	var steps := int(from.distance_to(to) / PATH_CHECK_STEP)
	for i in range(1, steps):
		if not _is_walkable.call(from.lerp(to, float(i) / steps)):
			return false
	return true


func _build_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	SpriteSheets.add_animation(frames, "idle", IDLE_TEXTURE, FRAME_SIZE, 8.0)
	SpriteSheets.add_animation(frames, "run", RUN_TEXTURE, FRAME_SIZE, 10.0)
	SpriteSheets.add_animation(frames, "run_axe", RUN_AXE_TEXTURE, FRAME_SIZE, 10.0)
	SpriteSheets.add_animation(frames, "chop", CHOP_TEXTURE, FRAME_SIZE, 10.0)
	return frames
