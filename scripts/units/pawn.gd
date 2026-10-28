class_name Pawn
extends Node2D
## Aldeão. Por enquanto só fica parado (animação idle); coleta e construção virão depois.

const IDLE_TEXTURE := preload("res://assets/Units/Blue Units/Pawn/Pawn_Idle.png")
const FRAME_SIZE := Vector2i(192, 192)
const IDLE_FRAMES := 8
const IDLE_FPS := 8.0
## Altura (em px, a partir do topo do frame) onde ficam os pés do personagem.
const FEET_Y := 127

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	_sprite.sprite_frames = _build_frames()
	# Origem do nó nos pés, para o y_sort ordenar corretamente.
	_sprite.offset = Vector2(0, FRAME_SIZE.y / 2.0 - FEET_Y)
	_sprite.play("idle")
	# Começa em um frame aleatório para vários aldeões não ficarem sincronizados.
	_sprite.frame = randi() % IDLE_FRAMES


func _build_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", IDLE_FPS)
	frames.rename_animation("default", "idle")
	for i in IDLE_FRAMES:
		var atlas := AtlasTexture.new()
		atlas.atlas = IDLE_TEXTURE
		atlas.region = Rect2(Vector2(i * FRAME_SIZE.x, 0), Vector2(FRAME_SIZE))
		frames.add_frame("idle", atlas)
	return frames
