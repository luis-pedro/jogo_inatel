class_name Sheep
extends Gatherable
## Ovelha, a fonte de comida. Anda de uma célula para outra sem se afastar do seu rebanho
## (ver `Flock`) e de vez em quando dá uma corrida. Com um aldeão reservado ela para; ele a abate com alguns golpes e depois recolhe
## a carne do chão. Duas adultas juntas dão cria, repondo o rebanho.

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
const RUN_SPEED := 130.0
## O pack tem uma só animação de movimento: mais lenta andando, acelerada correndo.
const WALK_FPS := 7.0
const RUN_FPS := 14.0
## Segundos entre uma corrida e outra, para cada ovelha (mín., máx.).
const RUN_INTERVAL := Vector2(12.0, 30.0)
## Quantas células ela percorre numa corrida (mín., máx.).
const RUN_STEPS := Vector2i(2, 4)
const PAUSE_TIME := Vector2(2.0, 5.0)  # segundos entre um passo e outro (mín., máx.)
## Pausa curtíssima para quem ficou longe do rebanho alcançar o grupo.
const CATCH_UP_PAUSE := Vector2(0.1, 0.6)
const STEP_CHANCE := 0.6
## Distância máxima (em células) que a ovelha fica do centro do rebanho.
const FLOCK_RADIUS := 2.0
## Duração do crescimento de uma ovelha recém-nascida.
const GROW_SECONDS := 1.5
const LAMB_SCALE := 0.3
const HITS_TO_KILL := 3
## Reação a um golpe: cor do clarão, achatamento, recuo (px) e duração.
const HIT_COLOR := Color(1.0, 0.35, 0.35)
const HIT_SQUASH := Vector2(1.25, 0.75)
const HIT_KNOCKBACK := 8.0
const HIT_SECONDS := 0.3
## Quanta comida uma ovelha dá (mín., máx.). Com a mochila de 15, são 1 ou 2 viagens.
const FOOD_RANGE := Vector2i(12, 30)

var stage := Stage.ALIVE
## Comida que ela ainda tem.
var food := 0
## Centro do rebanho: a ovelha fica perto desta célula. O `Flock` a atualiza.
var herd_cell := Vector2i.ZERO

var _world: World
var _previous_cell := Vector2i.ZERO
var _destination := Vector2.ZERO
var _moving := false
var _pause := 0.0
var _hits := 0
var _growing := false
var _hit_tween: Tween
## Segundos até a próxima corrida e passos que faltam na corrida atual (0 = andando).
var _run_cooldown := 0.0
var _run_steps_left := 0
var _running := false
var _last_direction := Vector2i.ZERO

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


func _init() -> void:
	resource_type = "food"


## Mapa por onde a ovelha anda. Chamar antes de entrar na árvore da cena.
func setup(world: World) -> void:
	_world = world


func _ready() -> void:
	super()
	food = randi_range(FOOD_RANGE.x, FOOD_RANGE.y)
	herd_cell = cell

	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	SpriteSheets.add_animation(frames, "idle", IDLE_TEXTURE, FRAME_SIZE, 8.0)
	SpriteSheets.add_animation(frames, "move", MOVE_TEXTURE, FRAME_SIZE, WALK_FPS)
	SpriteSheets.add_animation(frames, "run", MOVE_TEXTURE, FRAME_SIZE, RUN_FPS)
	SpriteSheets.add_animation(frames, "graze", GRAZE_TEXTURE, FRAME_SIZE, 8.0)
	SpriteSheets.add_animation(frames, "meat", MEAT_TEXTURE, MEAT_FRAME_SIZE, 1.0)
	_sprite.sprite_frames = frames
	# Origem do nó nos pés, para o y_sort ordenar corretamente.
	_sprite.offset = Vector2(0, FRAME_SIZE.y / 2.0 - FEET_Y)
	_sprite.flip_h = randf() < 0.5
	_set_click_size(Vector2(56, 48))
	_start_pause()
	_run_cooldown = roll_run_interval()
	_sprite.frame = randi() % frames.get_frame_count(_sprite.animation)


func _process(delta: float) -> void:
	if stage != Stage.ALIVE:
		return
	_run_cooldown -= delta
	if _moving:
		var speed := RUN_SPEED if _running else WALK_SPEED
		position = position.move_toward(_destination, speed * delta)
		if position == _destination:
			_finish_step()
		return
	if worker != null:
		# Reservada: termina o passo e fica parada esperando o aldeão.
		_stop_running()
		if _sprite.animation != &"idle":
			_sprite.play("idle")
		return
	if _run_cooldown <= 0.0:
		_start_running()
		return
	_pause -= delta
	if _pause <= 0.0:
		if _is_straying() or randf() < STEP_CHANCE:
			_try_step()
		else:
			_start_pause()


## O rebanho mudou de lugar: sai logo atrás dele (com um pequeno atraso para não irem todas juntas).
func follow(new_herd_cell: Vector2i) -> void:
	herd_cell = new_herd_cell
	_pause = minf(_pause, randf_range(0.0, 1.0))


## Sorteia quanto tempo falta para a próxima corrida.
func roll_run_interval() -> float:
	return randf_range(RUN_INTERVAL.x, RUN_INTERVAL.y)


## Dispara por algumas células, sem sair de perto do rebanho.
func _start_running() -> void:
	_run_cooldown = roll_run_interval()
	_run_steps_left = randi_range(RUN_STEPS.x, RUN_STEPS.y)
	_last_direction = Vector2i.ZERO
	_try_step()


func _stop_running() -> void:
	_run_steps_left = 0
	_running = false


## Ovelha recém-nascida: aparece pequena e cresce; só depois pode ser caçada.
func grow_in() -> void:
	_growing = true
	_set_targetable(false)
	_sprite.scale = Vector2.ONE * LAMB_SCALE
	var tween := create_tween()
	tween.tween_property(_sprite, "scale", Vector2.ONE, GROW_SECONDS) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		_growing = false
		_set_targetable(true)
	)


## Viva, adulta e sem ninguém atrás dela.
func can_breed() -> bool:
	return stage == Stage.ALIVE and not _growing and worker == null


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


## O pack não tem sprite de ovelha apanhando, então a reação é feita por código: clarão
## vermelho, achatada, um recuo para longe do aldeão e um tufo de lã.
func react_to_hit(from: Vector2) -> void:
	if stage != Stage.ALIVE:
		return
	var away := -1.0 if from.x > position.x else 1.0
	_reset_hit_effect()
	_sprite.modulate = HIT_COLOR
	_sprite.scale = HIT_SQUASH
	_sprite.position.x = away * HIT_KNOCKBACK
	# Tudo volta ao normal ao mesmo tempo, com um leve balanço elástico.
	_hit_tween = create_tween().set_parallel()
	_hit_tween.tween_property(_sprite, "modulate", Color.WHITE, HIT_SECONDS)
	_hit_tween.tween_property(_sprite, "scale", Vector2.ONE, HIT_SECONDS) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hit_tween.tween_property(_sprite, "position:x", 0.0, HIT_SECONDS) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_spawn_dust(Vector2(-away * 14.0, -22), 0.7)


func _reset_hit_effect() -> void:
	if _hit_tween:
		_hit_tween.kill()
	_sprite.modulate = Color.WHITE
	_sprite.scale = Vector2.ONE
	_sprite.position = Vector2.ZERO


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


## Passa para uma célula vizinha livre sem se afastar do rebanho (ou, se estiver longe, para uma
## que a aproxime dele).
func _try_step() -> void:
	var free: Array[Vector2i] = []
	for direction: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if _world.is_cell_free(cell + direction):
			free.append(cell + direction)
	var distance := _herd_distance(cell)
	var options := free.filter(func(next: Vector2i):
		return _herd_distance(next) < distance if _is_straying() else _herd_distance(next) <= FLOCK_RADIUS)
	# Longe e sem passo que aproxime (algo no caminho): anda para qualquer lado livre e contorna.
	if options.is_empty() and _is_straying():
		options = free
	if options.is_empty():
		_stop_running()
		_start_pause()
		return
	_running = _run_steps_left > 0
	_previous_cell = cell
	# Correndo, segue em linha reta enquanto der.
	var straight := cell + _last_direction
	cell = straight if _running and straight in options else options.pick_random()
	_last_direction = cell - _previous_cell
	# Durante o passo ocupa as duas células; a antiga é liberada na chegada.
	_world.occupy_cell(cell)
	_destination = position + Vector2((cell - _previous_cell) * World.TILE_SIZE)
	_moving = true
	if cell.x != _previous_cell.x:
		_sprite.flip_h = cell.x < _previous_cell.x
	_sprite.play("run" if _running else "move")
	if _running:
		_run_steps_left -= 1
		# Poeira levantada para trás; fica no chão, no ponto de onde ela saiu.
		_spawn_dust(Vector2(-_last_direction.x * 18.0, -8), 0.6, true)


func _herd_distance(from_cell: Vector2i) -> float:
	return Vector2(from_cell - herd_cell).length()


func _is_straying() -> bool:
	return _herd_distance(cell) > FLOCK_RADIUS


func _finish_step() -> void:
	_moving = false
	_world.release_cell(_previous_cell)
	# Numa corrida, emenda o próximo passo sem parar (a não ser que tenham mandado caçá-la).
	if _run_steps_left > 0 and worker == null and stage == Stage.ALIVE:
		_try_step()
	else:
		_stop_running()
		_start_pause()


func _start_pause() -> void:
	var time := CATCH_UP_PAUSE if _is_straying() else PAUSE_TIME
	_pause = randf_range(time.x, time.y)
	_sprite.play("graze" if randf() < 0.5 else "idle")


func _die() -> void:
	_run_steps_left = 0
	if _moving:
		position = _destination
		_finish_step()
	stage = Stage.MEAT
	set_process(false)
	_reset_hit_effect()
	_sprite.flip_h = false
	_sprite.offset = Vector2(0, MEAT_FRAME_SIZE.y / 2.0 - MEAT_FEET_Y)
	_sprite.play("meat")
	_spawn_dust(Vector2(0, -18), 1.4)


## Nuvem de poeira (ou lã) que toca uma vez e se remove. Por padrão é filha da ovelha: aparece
## por cima dela e a acompanha. Com `on_ground`, fica parada no mapa e é desenhada atrás de
## todas as entidades, porque o nó `World` vem antes de `Entities` na cena.
func _spawn_dust(offset: Vector2, size: float, on_ground := false) -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	SpriteSheets.add_animation(frames, "dust", DUST_TEXTURE, DUST_FRAME_SIZE, 12.0, false)
	var puff := AnimatedSprite2D.new()
	puff.sprite_frames = frames
	puff.position = offset
	puff.scale = Vector2.ONE * size
	puff.animation_finished.connect(puff.queue_free)
	if on_ground:
		puff.position = _world.to_local(global_position + offset)
		_world.add_child(puff)
	else:
		add_child(puff)
	puff.play("dust")
