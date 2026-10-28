class_name BuildingData
extends Resource
## Descreve um tipo de construção. Novos prédios = novo .tres em data/buildings/.

@export var display_name: String
@export var texture: Texture2D
## Área ocupada no chão, em tiles. A parte do sprite acima dela (telhado) só é visual.
@export var footprint := Vector2i(2, 2)
## Custo em recursos, ex.: {"wood": 20}.
@export var cost: Dictionary = {}
