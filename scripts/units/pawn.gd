class_name Pawn
extends Node2D
## Aldeão. Sem tarefa, ele anda um pouco pela vila e para, em ciclo (idle ⇄ andar).
## Coleta e construção virão depois.

enum State { IDLE, WALK }

const IDLE_TEXTURE := preload("res://assets/Units/Blue Units/Pawn/Pawn_Idle.png")
const RUN_TEXTURE := preload("res://assets/Units/Blue Units/Pawn/Pawn_Run.png")
const FRAME_SIZE := Vector2i(192, 192)
## Altura (em px, a partir do topo do frame) onde ficam os pés do personagem.
const FEET_Y := 127

const WALK_SPEED := 55.0
const WANDER_RADIUS := 220.0
const IDLE_TIME := Vector2(1.5, 4.0)  # segundos (mín., máx.)
const MIN_WALK_DISTANCE := 60.0
const PATH_CHECK_STEP := 16.0
const TARGET_ATTEMPTS := 8

var _state := State.IDLE
var _timer := 0.0
var _target := Vector2.ZERO
var _home := Vector2.ZERO
var _is_walkable := func(_point: Vector2) -> bool: return true

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


## Define o ponto ao redor do qual o aldeão passeia e a regra de onde ele pode pisar.
## Chamar antes de entrar na árvore da cena.
func setup(home: Vector2, is_walkable: Callable) -> void:
	_home = home
	_is_walkable = is_walkable


func _ready() -> void:
	_sprite.sprite_frames = _build_frames()
	# Origem do nó nos pés, para o y_sort ordenar corretamente.
	_sprite.offset = Vector2(0, FRAME_SIZE.y / 2.0 - FEET_Y)
	_start_idle()
	# Começa em um frame (e com um tempo de espera) aleatório para os aldeões não ficarem sincronizados.
	_sprite.frame = randi() % _sprite.sprite_frames.get_frame_count("idle")
	_timer = randf_range(0.0, IDLE_TIME.y)


func _physics_process(delta: float) -> void:
	match _state:
		State.IDLE:
			_timer -= delta
			if _timer <= 0.0:
				_try_start_walk()
		State.WALK:
			var to_target := _target - position
			var step := WALK_SPEED * delta
			if to_target.length() <= step:
				position = _target
				_start_idle()
			else:
				position += to_target.normalized() * step


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
	_add_animation(frames, "idle", IDLE_TEXTURE, 8.0)
	_add_animation(frames, "run", RUN_TEXTURE, 10.0)
	return frames


## Fatia a faixa horizontal de frames de uma textura numa animação.
func _add_animation(frames: SpriteFrames, anim: String, texture: Texture2D, fps: float) -> void:
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	for i in texture.get_width() / FRAME_SIZE.x:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(Vector2(i * FRAME_SIZE.x, 0), Vector2(FRAME_SIZE))
		frames.add_frame(anim, atlas)
