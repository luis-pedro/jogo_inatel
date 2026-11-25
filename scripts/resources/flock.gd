class_name Flock
extends Node
## Um rebanho: decide para onde o grupo vai (as ovelhas acompanham o centro) e faz nascer
## ovelhas novas, uma de cada vez. Só nasce quando há pelo menos duas adultas juntas, e o
## rebanho nunca passa da quantidade com que começou o jogo.

## Segundos até o rebanho se deslocar de novo (mín., máx.).
const MOVE_TIME := Vector2(7.0, 12.0)
## Quantas células o centro pode se afastar do pasto onde o rebanho nasceu.
const ROAM_RADIUS := 2.0
## Segundos até nascer uma ovelha para repor o rebanho (mín., máx.).
const RESPAWN_TIME := Vector2(45.0, 90.0)
## Distância máxima (em células) entre duas adultas para contarem como "juntas".
const PARENT_DISTANCE := 3.0
## Se não houver lugar para nascer (ex.: construíram no pasto), tenta de novo depois.
const RESPAWN_RETRY_SECONDS := 5.0

## Célula em volta da qual as ovelhas ficam agora.
var center := Vector2i.ZERO
var members: Array[Sheep] = []

var _world: World
var _home := Vector2i.ZERO
## Limite do rebanho: quantas ovelhas ele tinha no começo.
var _size := 0
var _spawn_sheep: Callable  # func(cell: Vector2i) -> Sheep
var _move_left := 0.0
var _respawn_left := 0.0


## `spawn_sheep` cria uma ovelha na célula dada e a devolve. Chamar antes de `populate()`.
func setup(world: World, home: Vector2i, size: int, spawn_sheep: Callable) -> void:
	_world = world
	_home = home
	center = home
	_size = size
	_spawn_sheep = spawn_sheep


## Cria as ovelhas iniciais.
func populate() -> void:
	var cells := _free_cells_around(center)
	for i in mini(_size, cells.size()):
		_add_member(cells[i])
	# Se não couberam todas, o limite é o que de fato nasceu.
	_size = members.size()
	_move_left = randf_range(MOVE_TIME.x, MOVE_TIME.y)
	_respawn_left = roll_respawn_time()


## Sorteia quanto tempo leva para nascer a próxima ovelha.
func roll_respawn_time() -> float:
	return randf_range(RESPAWN_TIME.x, RESPAWN_TIME.y)


func _process(delta: float) -> void:
	_move_left -= delta
	if _move_left <= 0.0:
		_move_left = randf_range(MOVE_TIME.x, MOVE_TIME.y)
		_move_herd()

	# Sem um casal junto a contagem fica parada (e um rebanho com menos de duas não se recupera).
	if members.size() < _size and has_parents():
		_respawn_left -= delta
		if _respawn_left <= 0.0:
			_respawn()


## Há duas ovelhas adultas, livres e perto uma da outra?
func has_parents() -> bool:
	var adults := members.filter(func(sheep: Sheep): return sheep.can_breed())
	for i in adults.size():
		for j in range(i + 1, adults.size()):
			if Vector2(adults[i].cell - adults[j].cell).length() <= PARENT_DISTANCE:
				return true
	return false


## Escolhe um novo centro perto do pasto e chama as ovelhas.
func _move_herd() -> void:
	# Enquanto uma ovelha é caçada o grupo espera, para ela não ficar para trás.
	if members.any(func(sheep: Sheep): return sheep.worker != null):
		return
	var options: Array[Vector2i] = []
	for x in range(-2, 3):
		for y in range(-2, 3):
			var next := center + Vector2i(x, y)
			if Vector2(x, y).length() >= 1.5 and Vector2(next - _home).length() <= ROAM_RADIUS \
					and _world.is_buildable(next) and not _world.is_blocked(next):
				options.append(next)
	if options.is_empty():
		return
	center = options.pick_random()
	for sheep in members:
		sheep.follow(center)


func _respawn() -> void:
	var cells := _free_cells_around(center)
	if cells.is_empty():
		_respawn_left = RESPAWN_RETRY_SECONDS
		return
	_add_member(cells[0]).grow_in()
	_respawn_left = roll_respawn_time()


## Células livres perto de `cell`, em ordem sorteada.
func _free_cells_around(cell: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var reach := int(Sheep.FLOCK_RADIUS)
	for x in range(-reach, reach + 1):
		for y in range(-reach, reach + 1):
			var candidate := cell + Vector2i(x, y)
			if Vector2(x, y).length() <= Sheep.FLOCK_RADIUS and _world.is_cell_free(candidate):
				cells.append(candidate)
	cells.shuffle()
	return cells


func _add_member(cell: Vector2i) -> Sheep:
	var sheep: Sheep = _spawn_sheep.call(cell)
	sheep.herd_cell = center
	sheep.removed.connect(_on_member_removed)
	members.append(sheep)
	return sheep


func _on_member_removed(source: Gatherable) -> void:
	# A contagem para nascer outra começa quando a primeira falta aparece.
	if members.size() == _size:
		_respawn_left = roll_respawn_time()
	members.erase(source as Sheep)
