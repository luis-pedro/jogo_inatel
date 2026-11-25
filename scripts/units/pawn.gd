class_name Pawn
extends Node2D
## Aldeão. Sem tarefa, passeia pela vila (idle ⇄ andar). Pode erguer uma obra (vai até ela e
## martela até ficar pronta). Com a tarefa de coletar (árvore ou ouro):
## vai até o recurso, trabalha até encher a mochila (ou ele acabar), leva a carga até a porta da
## casa, entrega (só aí o estoque sobe) e volta enquanto ainda houver o que coletar.

enum State { IDLE, WALK, TO_SOURCE, WAIT_GROWTH, GATHER, UPROOT, TO_HOME, TO_SITE, BUILD }
## O que o jogador mandou fazer: coletar o recurso ou arrancar um toco.
enum Goal { GATHER, UPROOT }

const IDLE_TEXTURE := preload("res://assets/Units/Blue Units/Pawn/Pawn_Idle.png")
const RUN_TEXTURE := preload("res://assets/Units/Blue Units/Pawn/Pawn_Run.png")
const RUN_AXE_TEXTURE := preload("res://assets/Units/Blue Units/Pawn/Pawn_Run Axe.png")
const RUN_WOOD_TEXTURE := preload("res://assets/Units/Blue Units/Pawn/Pawn_Run Wood.png")
const CHOP_TEXTURE := preload("res://assets/Units/Blue Units/Pawn/Pawn_Interact Axe.png")
const RUN_HAMMER_TEXTURE := preload("res://assets/Units/Blue Units/Pawn/Pawn_Run Hammer.png")
const BUILD_TEXTURE := preload("res://assets/Units/Blue Units/Pawn/Pawn_Interact Hammer.png")
const RUN_PICKAXE_TEXTURE := preload("res://assets/Units/Blue Units/Pawn/Pawn_Run Pickaxe.png")
const RUN_GOLD_TEXTURE := preload("res://assets/Units/Blue Units/Pawn/Pawn_Run Gold.png")
const MINE_TEXTURE := preload("res://assets/Units/Blue Units/Pawn/Pawn_Interact Pickaxe.png")
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
## Como o aldeão trabalha em cada recurso:
## - capacity: quanto cabe na mochila antes de levar para casa. Madeira 13: árvore grande
##   (14 a 25) dá 2 viagens e pequena (5 a 12) dá 1. Ouro 30: minério pequeno (20 a 30) dá 1
##   viagem, médio (40 a 60) dá 2 e grande (70 a 90) dá 3.
## - per_swing: quanto tira a cada golpe (um ciclo da animação de trabalho).
## - travel / work / carry: animações de ida, trabalho e volta carregado.
const JOBS := {
	"wood": {"capacity": 13, "per_swing": 2, "travel": "run_axe", "work": "chop", "carry": "run_wood"},
	"gold": {"capacity": 30, "per_swing": 4, "travel": "run_pickaxe", "work": "mine", "carry": "run_gold"},
}
## Machadadas (ciclos da animação) para arrancar um toco.
const UPROOT_SWINGS := 3

var _state := State.IDLE
var _timer := 0.0
var _target := Vector2.ZERO
## Porta da casa do aldeão: centro do passeio e ponto de entrega.
var _home := Vector2.ZERO
var _world: World

var _source: Gatherable
var _site: Building
var _goal := Goal.GATHER
var _uproot_swings := 0
var _path := PackedVector2Array()
var _path_index := 0
var _carried := 0
var _carried_type := ""
## Centro da célula vizinha de onde o aldeão se aproximou do recurso: volta por ela ao sair.
var _approach_point := Vector2.ZERO
var _at_source := false

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


## Manda o aldeão trabalhar em `source` seguindo `path` (pontos do mundo): coletar, ou arrancar
## se for um toco. Reserva ele em GameState e reserva o recurso (toco reservado não cresce).
func assign_gather(source: Gatherable, path: PackedVector2Array) -> void:
	if not is_available() or not GameState.reserve_villager():
		return
	_source = source
	var tree := source as WoodTree
	_goal = Goal.UPROOT if tree != null and tree.is_stump() else Goal.GATHER
	_source.worker = self  # reservado durante todas as viagens
	_walk_to_source(path)


## Aldeão disponível com o menor caminho, calculado por `path_for(pawn)`. Vazio se nenhum chega;
## senão {"pawn": Pawn, "path": PackedVector2Array}.
static func find_nearest_available(units: Array[Node], path_for: Callable) -> Dictionary:
	var best := {}
	for unit in units:
		var pawn := unit as Pawn
		if pawn == null or not pawn.is_available():
			continue
		var path: PackedVector2Array = path_for.call(pawn)
		if not path.is_empty() and (best.is_empty() or path.size() < best.path.size()):
			best = {"pawn": pawn, "path": path}
	return best


## Manda o aldeão erguer a obra `site`, andando por `path` até o lado dela.
func assign_build(site: Building, path: PackedVector2Array) -> void:
	if not is_available() or not GameState.reserve_villager():
		return
	_site = site
	_begin_path(State.TO_SITE, path, "run_hammer")


func _physics_process(delta: float) -> void:
	match _state:
		State.IDLE:
			_timer -= delta
			if _timer <= 0.0:
				_try_start_walk()
		State.WALK:
			if _step_towards(_target, delta, WALK_SPEED):
				_start_idle()
		State.TO_SOURCE, State.TO_HOME, State.TO_SITE:
			_follow_path(delta)
		State.BUILD:
			_site.advance_construction(delta)
			if not _site.under_construction:
				_finish_building()


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
	match _state:
		State.TO_SOURCE:
			_arrive_at_source()
		State.TO_SITE:
			_arrive_at_site()
		State.TO_HOME:
			_deliver()


func _arrive_at_site() -> void:
	_state = State.BUILD
	var site_center_x := _site.position.x + _site.data.footprint.x * World.TILE_SIZE / 2.0
	_sprite.flip_h = site_center_x < position.x
	_sprite.play("build")


func _finish_building() -> void:
	_site = null
	GameState.release_villager()
	_start_idle()


## Segue `path` até o recurso: o último ponto (centro da célula vizinha) é trocado pelo ponto de
## trabalho, para o aldeão ir direto até lá, sem passar dele e voltar.
func _walk_to_source(path: PackedVector2Array) -> void:
	if not path.is_empty():
		_approach_point = path[path.size() - 1]
		path[path.size() - 1] = _source.get_work_position(_approach_point)
	_begin_path(State.TO_SOURCE, path, JOBS[_source.resource_type].travel)


func _arrive_at_source() -> void:
	_at_source = true
	_sprite.flip_h = _source.position.x < position.x
	var tree := _source as WoodTree
	if tree != null and tree.stage == WoodTree.Stage.SAPLING:
		# A muda ainda está crescendo: espera ela ficar adulta e só então decide o que fazer.
		_state = State.WAIT_GROWTH
		_sprite.play("idle")
		tree.regrown.connect(_arrive_at_source, CONNECT_ONE_SHOT)
	elif _source.can_harvest():
		# Vale também para árvore que voltou a crescer quando a ordem era arrancar o toco: corta
		# primeiro. Com a pausa do crescimento isso não deveria acontecer, mas assim não trava.
		_state = State.GATHER
		_sprite.play(JOBS[_source.resource_type].work)
	elif _goal == Goal.UPROOT and tree != null and tree.is_stump():
		_state = State.UPROOT
		_uproot_swings = 0
		_sprite.play("chop")
	else:
		_finish_task()


## Chamado a cada ciclo completo de uma animação em loop; trabalhando, cada ciclo é um golpe.
func _on_animation_looped() -> void:
	match _state:
		State.GATHER:
			var job: Dictionary = JOBS[_source.resource_type]
			_carried_type = _source.resource_type
			_carried += _source.harvest(mini(job.per_swing, job.capacity - _carried))
			var exhausted := not _source.can_harvest()
			var full: bool = _carried >= job.capacity
			# Um minério esgotado sai do mapa no fim do frame: a referência não pode mais ser usada.
			if _source.is_queued_for_deletion():
				_source = null
			if full or exhausted:
				_go_home()
		State.UPROOT:
			_uproot_swings += 1
			if _uproot_swings >= UPROOT_SWINGS:
				_finish_uproot()


func _finish_uproot() -> void:
	_carried_type = "wood"
	_carried += (_source as WoodTree).uproot()
	# A árvore sai do jogo no fim do frame: daqui em diante a referência não pode mais ser usada.
	_source = null
	_go_home()


func _go_home() -> void:
	# Trabalhando por trás, o aldeão fica dentro da célula do recurso; nesse caso sai pela célula
	# vizinha por onde chegou.
	var leave_through_approach := _at_source and not _world.is_point_walkable(position)
	var path := _world.find_path(_approach_point if leave_through_approach else position, _home)
	if path.is_empty():
		# Sem caminho até a porta (ex.: cercada por construções): entrega aqui mesmo,
		# para a carga não se perder nem o aldeão ficar preso na tarefa.
		_deliver()
		return
	if leave_through_approach:
		path.insert(0, _approach_point)
	_at_source = false
	_begin_path(State.TO_HOME, path, JOBS[_carried_type].carry)


func _deliver() -> void:
	if _carried > 0:
		GameState.add_resource(_carried_type, _carried)
		_carried = 0
	# Volta ao recurso se ainda há trabalho nele e o caminho continua existindo.
	if _should_return_to_source():
		var path := _world.find_path_to_adjacent(position, _source.cell)
		if not path.is_empty():
			_walk_to_source(path)
			return
	_finish_task()


## Ainda há o que fazer: recurso para coletar ou, se a ordem era arrancar, um toco.
func _should_return_to_source() -> bool:
	if _source == null or not is_instance_valid(_source):
		return false
	if _source.can_harvest():
		return true
	var tree := _source as WoodTree
	return _goal == Goal.UPROOT and tree != null and tree.is_stump()


func _finish_task() -> void:
	if _at_source and not _world.is_point_walkable(position):
		# Terminou em cima da célula do recurso: volta à célula vizinha.
		position = _approach_point
	_at_source = false
	if _source != null and is_instance_valid(_source):
		_source.worker = null  # libera o recurso (e um toco volta a contar o crescimento)
	_source = null
	_goal = Goal.GATHER
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
	SpriteSheets.add_animation(frames, "run_hammer", RUN_HAMMER_TEXTURE, FRAME_SIZE, 10.0)
	SpriteSheets.add_animation(frames, "build", BUILD_TEXTURE, FRAME_SIZE, 6.0)
	SpriteSheets.add_animation(frames, "run_pickaxe", RUN_PICKAXE_TEXTURE, FRAME_SIZE, 10.0)
	SpriteSheets.add_animation(frames, "run_gold", RUN_GOLD_TEXTURE, FRAME_SIZE, 10.0)
	SpriteSheets.add_animation(frames, "mine", MINE_TEXTURE, FRAME_SIZE, 10.0)
	return frames
