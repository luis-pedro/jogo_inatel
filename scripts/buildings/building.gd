class_name Building
extends Node2D
## Construção posta no mapa. A origem do nó é o canto inferior esquerdo da área ocupada
## no chão, para o y_sort ordenar os prédios pela base.
## Em obra, mostra o canteiro até um aldeão chegar; depois é erguida de baixo para cima
## enquanto ele chama `advance_construction()`.

signal construction_finished(building: Building)

const DUST_TEXTURE := preload("res://assets/Particle FX/Dust_02.png")
const DUST_FRAME_SIZE := Vector2i(64, 64)
## A nuvem ocupa quase todo o frame de 64 px; com esta escala ela cobre a casa inteira.
const DUST_SCALE := 3.0
## Altura do centro da nuvem, como fração da altura do sprite do prédio (a partir da base).
const DUST_CENTER_HEIGHT := 0.52
const BAR_SIZE := Vector2(90, 12)
var data: BuildingData
var cell: Vector2i
## Índice da orientação (posição em `data.textures`).
var variant := 0
var under_construction := false
## De 0 (acabou de ser marcada) a 1 (pronta).
var progress := 0.0

var _tile_size := 64
## Nós que só existem durante a obra (canteiro, parte já erguida, poeira e barra).
var _site_ground: Sprite2D
var _reveal: Sprite2D
var _bar: ProgressBar
var _dust: AnimatedSprite2D

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
## Até o primeiro `advance_construction()` (o aldeão chegar) só aparece o canteiro.
func start_construction() -> void:
	under_construction = true
	progress = 0.0
	_sprite.visible = false
	_create_construction_site()


## Soma trabalho à obra (chamado pelo aldeão construtor a cada frame de física).
func advance_construction(delta: float) -> void:
	if not under_construction:
		return
	if _reveal == null:
		_create_construction_visuals()
	progress = minf(progress + delta / data.build_time, 1.0)
	_update_construction_visual()
	if progress >= 1.0:
		_finish_construction()


## Chão marcado com estacas e corda, onde o prédio vai ser erguido.
func _create_construction_site() -> void:
	var area := Vector2(data.footprint * _tile_size)

	_site_ground = Sprite2D.new()
	_site_ground.texture = data.construction_site_texture
	_site_ground.centered = false
	_site_ground.position = Vector2(0, -area.y)
	if data.construction_site_texture != null:
		_site_ground.scale = area / data.construction_site_texture.get_size()
	add_child(_site_ground)


## Parte já erguida, poeira e barra de progresso.
func _create_construction_visuals() -> void:
	_reveal = Sprite2D.new()
	_reveal.texture = _sprite.texture
	_reveal.centered = false
	_reveal.region_enabled = true
	add_child(_reveal)

	var footprint_width := data.footprint.x * _tile_size
	_dust = _create_dust()
	_dust.position = Vector2(footprint_width / 2.0, -_sprite.texture.get_height() * DUST_CENTER_HEIGHT)

	_bar = _create_progress_bar()
	_bar.position = Vector2((footprint_width - BAR_SIZE.x) / 2.0, -_sprite.texture.get_height() - BAR_SIZE.y)
	add_child(_bar)


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
	_sprite.visible = true
	_site_ground.queue_free()
	_reveal.queue_free()
	_bar.queue_free()
	# A poeira toca uma última vez e se remove: o "puff" de obra pronta.
	_dust.sprite_frames.set_animation_loop("dust", false)
	_dust.animation_finished.connect(_dust.queue_free)
	_dust.frame = 0
	_dust.play("dust")
	_dust = null
	construction_finished.emit(self)


func _create_dust() -> AnimatedSprite2D:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	SpriteSheets.add_animation(frames, "dust", DUST_TEXTURE, DUST_FRAME_SIZE, 10.0)
	var puff := AnimatedSprite2D.new()
	puff.sprite_frames = frames
	puff.scale = Vector2.ONE * DUST_SCALE
	add_child(puff)
	puff.play("dust")
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
