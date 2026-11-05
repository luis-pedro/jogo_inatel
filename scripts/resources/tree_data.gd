class_name TreeData
extends Resource
## Descreve um tipo de árvore: sprite da árvore, sprite do toco e onde fica a base de cada um.
## Novos tipos = novo .tres em data/trees/.

@export var display_name: String
@export var tree_texture: Texture2D
## Tamanho de cada frame da faixa de animação da árvore.
@export var tree_frame_size := Vector2i(192, 256)
## Altura (px, a partir do topo do frame) onde fica a base do tronco da árvore.
@export var tree_feet_y := 228
@export var stump_texture: Texture2D
@export var stump_frame_size := Vector2i(192, 256)
## Altura (px, a partir do topo do frame) da base do toco. Difere da árvore em alguns tipos.
@export var stump_feet_y := 228
## Quanta madeira a árvore dá: sorteio entre estes valores (de novo a cada rebrota).
@export var wood_min := 12
@export var wood_max := 12
## Área clicável (px), com a base alinhada aos pés da árvore.
@export var click_size := Vector2(100, 170)
