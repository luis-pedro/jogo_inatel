class_name GoldData
extends Resource
## Descreve um tipo de minério de ouro. Novos tipos = novo .tres em data/gold/.

## Faixa de 6 frames de 128x128: o primeiro é a pedra parada, os outros o brilho.
@export var texture: Texture2D
@export var frame_size := Vector2i(128, 128)
## Altura (px, a partir do topo do frame) onde fica a base da pedra.
@export var feet_y := 70
## Quanto ouro o minério tem (sorteio entre estes valores). Pedras maiores têm mais e, com a
## mochila de 30, pedem mais viagens: pequena até 30 (1), média 31 a 60 (2), grande 61 a 90 (3).
@export var gold_min := 20
@export var gold_max := 30
## Área clicável (px), com a base alinhada aos pés.
@export var click_size := Vector2(40, 40)
