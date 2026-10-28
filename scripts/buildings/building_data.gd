class_name BuildingData
extends Resource
## Descreve um tipo de construção. Novos prédios = novo .tres em data/buildings/.

@export var display_name: String
## Uma textura por orientação (a tecla R alterna entre elas).
@export var textures: Array[Texture2D] = []
## Lado da porta de cada orientação (mesma ordem de `textures`): (0,1)=baixo, (-1,0)=esquerda...
@export var door_directions: Array[Vector2i] = []
## Área ocupada no chão, em tiles. A parte do sprite acima dela (telhado) só é visual.
@export var footprint := Vector2i(2, 2)
## Custo em recursos, ex.: {"wood": 20}.
@export var cost: Dictionary = {}
