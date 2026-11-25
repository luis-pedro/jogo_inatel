class_name Building
extends Node2D
## Construção posta no mapa. A origem do nó é o canto inferior esquerdo da área ocupada
## no chão, para o y_sort ordenar os prédios pela base.
## Em obra, aparece como uma "planta" translúcida que vai sendo erguida de baixo para cima
## enquanto um aldeão chama `advance_construction()`.

signal construction_finished(building: Building)

const DUST_TEXTURE := preload("res://assets/Particle FX/Dust_01.png")
const DUST_FRAME_SIZE := Vector2i(64, 64)
const DUST_PUFFS := 3
const BLUEPRINT_COLOR := Color(1.0, 1.0, 1.0, 0.35)
const BAR_SIZE := Vector2(90, 12)

var data: BuildingData
var cell: Vector2i
## Índice da orientação (posição em `data.textures`).
var variant := 0
var under_construction := false
## De 0 (acabou de ser marcada) a 1 (pronta).
var progress := 0.0

var _tile_size := 64
## Nós que só existem durante a obra (parte já erguida, poeira e barra).
var _reveal: Sprite2D
var _bar: ProgressBar
var _dust: Array[AnimatedSprite2D] = []

@onready var _sprite: Sprite2D = $Sprite2D


## Configura (ou reposiciona) o prédio. Pode ser chamado de novo depois de entrar na árvore.
func setup(building_data: BuildingData, origin_cell: Vector2i, tile_size: int, new_variant := 0) -> void:
	data = building_data
	cell = origin_cell
	variant = new_variant
	_tile_size = tile_size
	position = Vector2(origin_cell.x, origin_cell.y + data.footprint.y) * tile_size
	# Antes de _ready() o @onready ainda não existe; nesse caso o _ready() aplica o visual.
	if is_node_ready():
		_apply_sprite()


func _ready() -> void:
	_apply_sprite()


## Transforma o prédio em obra. Chamar depois de ele entrar na árvore da cena.
func start_construction() -> void:
	under_construction = true
	progress = 0.0
	_sprite.modulate = BLUEPRINT_COLOR

	_reveal = Sprite2D.new()
	_reveal.texture = _sprite.texture
	_reveal.centered = false
	_reveal.region_enabled = true
	add_child(_reveal)

	var footprint_width := data.footprint.x * _tile_size
	for i in DUST_PUFFS:
		var puff := _create_dust()
		puff.position = Vector2(footprint_width * (i + 0.5) / DUST_PUFFS, -8)
		_dust.append(puff)

	_bar = _create_progress_bar()
	_bar.position = Vector2((footprint_width - BAR_SIZE.x) / 2.0, -_sprite.texture.get_height() - BAR_SIZE.y)
	add_child(_bar)
	_update_construction_visual()


## Soma trabalho à obra (chamado pelo aldeão construtor a cada frame de física).
func advance_construction(delta: float) -> void:
	if not under_construction:
		return
	progress = minf(progress + delta / data.build_time, 1.0)
	_update_construction_visual()
	if progress >= 1.0:
		_finish_construction()


func _update_construction_visual() -> void:
	# Mostra só a fatia de baixo da textura, proporcional ao progresso.
	var size := _sprite.texture.get_size()
	var built_height := roundf(size.y * progress)
	_reveal.region_rect = Rect2(0, size.y - built_height, size.x, built_height)
	_reveal.offset = Vector2(_sprite.offset.x, -built_height)
	_reveal.visible = built_height > 0.0
	_bar.value = progress


func _finish_construction() -> void:
	under_construction = false
	_sprite.modulate = Color.WHITE
	_reveal.queue_free()
	_bar.queue_free()
	for puff in _dust:
		# A poeira termina o ciclo atual e se remove: um último "puff" de obra pronta.
		puff.sprite_frames.set_animation_loop("dust", false)
		puff.animation_finished.connect(puff.queue_free)
		puff.frame = 0
		puff.play("dust")
	_dust.clear()
	construction_finished.emit(self)


func _create_dust() -> AnimatedSprite2D:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	SpriteSheets.add_animation(frames, "dust", DUST_TEXTURE, DUST_FRAME_SIZE, 10.0)
	var puff := AnimatedSprite2D.new()
	puff.sprite_frames = frames
	puff.scale = Vector2(1.5, 1.5)
	add_child(puff)
	puff.play("dust")
	puff.frame = randi() % frames.get_frame_count("dust")
	return puff


func _create_progress_bar() -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = 1.0
	bar.step = 0.0
	bar.show_percentage = false
	bar.size = BAR_SIZE
	bar.z_index = 10  # por cima das árvores e casas vizinhas
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.95, 0.75, 0.2)
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


func _apply_sprite() -> void:
	var texture := data.textures[variant]
	_sprite.texture = texture
	_sprite.centered = false
	# Base do sprite na origem; sprite centralizado na largura da área ocupada.
	var footprint_width := data.footprint.x * _tile_size
	_sprite.offset = Vector2(-(texture.get_width() - footprint_width) / 2.0, -texture.get_height())
