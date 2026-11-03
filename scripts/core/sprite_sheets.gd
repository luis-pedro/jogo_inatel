class_name SpriteSheets
extends RefCounted
## Utilidades para montar animações a partir das faixas horizontais de frames do Tiny Swords.


## Fatia a textura (frames lado a lado, todos de `frame_size`) numa animação de `frames`.
static func add_animation(frames: SpriteFrames, anim: StringName, texture: Texture2D,
		frame_size: Vector2i, fps: float, loop := true) -> void:
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, loop)
	for i in texture.get_width() / frame_size.x:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(Vector2(i * frame_size.x, 0), Vector2(frame_size))
		frames.add_frame(anim, atlas)
