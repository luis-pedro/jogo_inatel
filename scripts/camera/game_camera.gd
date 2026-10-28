class_name GameCamera
extends Camera2D
## Câmera do reino: WASD/setas movem, botão do meio arrasta e a roda do mouse dá zoom.
## A inclinação "diagonal" do jogo vem da arte (visão 3/4 do Tiny Swords), não da câmera.

const PAN_SPEED := 800.0
const ZOOM_STEP := 0.1
const ZOOM_MIN := 0.5
const ZOOM_MAX := 2.0

var _target_zoom := 1.0


func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = 12.0


func _process(delta: float) -> void:
	var direction := Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	# Divide pelo zoom para a velocidade na tela ser a mesma em qualquer aproximação.
	position += direction * PAN_SPEED * delta / zoom.x

	var new_zoom := lerpf(zoom.x, _target_zoom, minf(delta * 12.0, 1.0))
	zoom = Vector2(new_zoom, new_zoom)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
		position -= event.relative / zoom.x
		# Arrastar não deve ser suavizado, senão a câmera "escorrega" atrás do mouse.
		reset_smoothing()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom_target(_target_zoom + ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom_target(_target_zoom - ZOOM_STEP)


## Limita a câmera ao retângulo do mundo (em pixels).
func set_world_limits(rect: Rect2i) -> void:
	limit_left = rect.position.x
	limit_top = rect.position.y
	limit_right = rect.end.x
	limit_bottom = rect.end.y


func _set_zoom_target(value: float) -> void:
	_target_zoom = clampf(value, ZOOM_MIN, ZOOM_MAX)
