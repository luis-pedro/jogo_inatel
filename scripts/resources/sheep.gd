class_name Sheep
extends Gatherable
## Ovelha, a fonte de comida. Pasta perto do rebanho, andando de uma célula para outra. Com um
## aldeão reservado ela para; ele a abate com alguns golpes e depois recolhe a carne do chão.
## Não renasce.

enum Stage { ALIVE, MEAT }

const IDLE_TEXTURE := preload("res://assets/Terrain/Resources/Meat/Sheep/Sheep_Idle.png")
const MOVE_TEXTURE := preload("res://assets/Terrain/Resources/Meat/Sheep/Sheep_Move.png")
const GRAZE_TEXTURE := preload("res://assets/Terrain/Resources/Meat/Sheep/Sheep_Grass.png")
const MEAT_TEXTURE := preload("res://assets/Terrain/Resources/Meat/Meat Resource/Meat Resource.png")
const DUST_TEXTURE := preload("res://assets/Particle FX/Dust_01.png")
const FRAME_SIZE := Vector2i(128, 128)
const MEAT_FRAME_SIZE := Vector2i(64, 64)
const DUST_FRAME_SIZE := Vector2i(64, 64)
## Altura (px, a partir do topo do frame) onde ficam os pés da ovelha e a base da carne.
const FEET_Y := 76
const MEAT_FEET_Y := 46

const WALK_SPEED := 40.0
const PAUSE_TIME := Vector2(2.0, 5.0)  # segundos entre um passo e outro (mín., máx.)
const STEP_CHANCE := 0.6
## Quantas células a ovelha pode se afastar de onde nasceu.
const PASTURE_RADIUS := 2
const HITS_TO_KILL := 3
## Quanta comida uma ovelha dá (mín., máx.). Com a mochila de 15, são 1 ou 2 viagens.
const FOOD_RANGE := Vector2i(12, 30)

var stage := Stage.ALIVE
## Comida que ela ainda tem.
var food := 0

var _world: World
var _home_cell := Vector2i.ZERO
var _previous_cell := Vector2i.ZERO
var _destination := Vector2.ZERO
var _moving := false
var _pause := 0.0
var _hits := 0

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


func _init() -> void:
	resource_type = "food"


## Mapa por onde a ovelha anda. Chamar antes de entrar na árvore da cena.
func setup(world: World) -> void:
	_world = world


func _ready() -> void:
	super()
	food = randi_range(FOOD_RANGE.x, FOOD_RANGE.y)
	_home_cell = cell

	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	SpriteSheets.add_animation(frames, "idle", IDLE_TEXTURE, FRAME_SIZE, 8.0)
	SpriteSheets.add_animation(frames, "move", MOVE_TEXTURE, FRAME_SIZE, 8.0)
	SpriteSheets.add_animation(frames, "graze", GRAZE_TEXTURE, FRAME_SIZE, 8.0)
	SpriteSheets.add_animation(frames, "meat", MEAT_TEXTURE, MEAT_FRAME_SIZE, 1.0)
	_sprite.sprite_frames = frames
	# Origem do nó nos pés, para o y_sort ordenar corretamente.
	_sprite.offset = Vector2(0, FRAME_SIZE.y / 2.0 - FEET_Y)
	_sprite.flip_h = randf() < 0.5
	_set_click_size(Vector2(56, 48))
	_start_pause()
	_sprite.frame = randi() % frames.get_frame_count(_sprite.animation)


func _process(delta: float) -> void:
	if stage != Stage.ALIVE:
		return
	if _moving:
		position = position.move_toward(_destination, WALK_SPEED * delta)
		if position == _destination:
			_finish_step()
		return
	if worker != null:
		# Reservada: termina o passo e fica parada esperando o aldeão.
		if _sprite.animation != &"idle":
			_sprite.play("idle")
		return
	_pause -= delta
	if _pause <= 0.0:
		if randf() < STEP_CHANCE:
			_try_step()
		else:
			_start_pause()


## Ovelhas não bloqueiam o caminho dos aldeões; só impedem que construam em cima delas.
func blocks_movement() -> bool:
	return false


## Onde ela vai estar quando parar (o aldeão calcula o golpe a partir daqui).
func get_anchor_position() -> Vector2:
	return _destination if _moving else position


func get_work_extent() -> Vector2:
	return Vector2(20, 40)


func can_harvest() -> bool:
	return food > 0


## Viva, cada chamada é um golpe (não rende comida). Abatida, retira a carne.
func harvest(amount: int) -> int:
	if stage == Stage.ALIVE:
		_hits += 1
		if _hits >= HITS_TO_KILL:
			_die()
		return 0
	var taken := mini(amount, food)
	food -= taken
	if taken > 0 and food == 0:
		_remove_from_map()
	return taken


## Passa para uma célula vizinha livre dentro do pasto.
func _try_step() -> void:
	var options: Array[Vector2i] = []
	for direction: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var next := cell + direction
		if Vector2(next - _home_cell).length() <= PASTURE_RADIUS and _world.is_cell_free(next):
			options.append(next)
	if options.is_empty():
		_start_pause()
		return
	_previous_cell = cell
	cell = options.pick_random()
	# Durante o passo ocupa as duas células; a antiga é liberada na chegada.
	_world.occupy_cell(cell)
	_destination = position + Vector2((cell - _previous_cell) * World.TILE_SIZE)
	_moving = true
	if cell.x != _previous_cell.x:
		_sprite.flip_h = cell.x < _previous_cell.x
	_sprite.play("move")


func _finish_step() -> void:
	_moving = false
	_world.release_cell(_previous_cell)
	_start_pause()


func _start_pause() -> void:
	_pause = randf_range(PAUSE_TIME.x, PAUSE_TIME.y)
	_sprite.play("graze" if randf() < 0.5 else "idle")


func _die() -> void:
	if _moving:
		position = _destination
		_finish_step()
	stage = Stage.MEAT
	set_process(false)
	_sprite.flip_h = false
	_sprite.offset = Vector2(0, MEAT_FRAME_SIZE.y / 2.0 - MEAT_FEET_Y)
	_sprite.play("meat")
	_spawn_dust()


## Nuvem de poeira que toca uma vez e se remove.
func _spawn_dust() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	SpriteSheets.add_animation(frames, "dust", DUST_TEXTURE, DUST_FRAME_SIZE, 12.0, false)
	var puff := AnimatedSprite2D.new()
	puff.sprite_frames = frames
	puff.position = Vector2(0, -18)
	puff.scale = Vector2(1.4, 1.4)
	puff.animation_finished.connect(puff.queue_free)
	add_child(puff)
	puff.play("dust")
