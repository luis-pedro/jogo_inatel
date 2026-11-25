class_name GoldOre
extends Gatherable
## Minério de ouro. É finito: não cresce de novo e, quando acaba, some e libera a célula.

## Tipo usado quando nenhum é definido antes de o minério entrar na cena.
const DEFAULT_DATA := preload("res://data/gold/gold1.tres")
const SHINE_FPS := 10.0
## Pausa entre um brilho e outro, em segundos (sorteada para cada pedra).
const SHINE_PAUSE := Vector2(2.0, 5.0)

## Tipo do minério (sprite e quantidade). Definir antes de entrar na cena.
@export var data: GoldData
## Ouro que ainda resta.
var gold := 0

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


func _init() -> void:
	resource_type = "gold"


func _ready() -> void:
	super()
	if data == null:
		data = DEFAULT_DATA
	gold = randi_range(data.gold_min, data.gold_max)

	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	SpriteSheets.add_animation(frames, "shine", data.texture, data.frame_size, SHINE_FPS)
	# O primeiro frame (pedra parada) dura bem mais: brilha de vez em quando sem precisar de Timer.
	var pause := randf_range(SHINE_PAUSE.x, SHINE_PAUSE.y)
	frames.set_frame("shine", 0, frames.get_frame_texture("shine", 0), pause * SHINE_FPS)
	_sprite.sprite_frames = frames
	# Origem do nó na base da pedra, para o y_sort ordenar corretamente.
	_sprite.offset = Vector2(0, data.frame_size.y / 2.0 - data.feet_y)
	_sprite.play("shine")
	_sprite.frame_progress = randf()
	_set_click_size(data.click_size)


## A área clicável acompanha o desenho da pedra, então serve de medida do tamanho dela.
func get_work_extent() -> Vector2:
	return Vector2(data.click_size.x / 2.0 - 4.0, data.click_size.y)


func can_harvest() -> bool:
	return gold > 0


func harvest(amount: int) -> int:
	var taken := mini(amount, gold)
	gold -= taken
	if taken > 0 and gold == 0:
		_remove_from_map()
	return taken
