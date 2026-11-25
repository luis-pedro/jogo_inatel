class_name Gatherable
extends Area2D
## Base de tudo que um aldeão coleta com um clique (árvore, minério de ouro...).
## É uma Area2D na camada `collectibles` só para o clique do jogador achá-la.

## Saiu do mapa de vez; quem bloqueou a célula deve liberá-la.
signal removed(source: Gatherable)

## Recurso que entrega ao estoque ("wood", "gold"). Definido por quem herda.
var resource_type := ""
## Célula do mapa que ocupa.
var cell: Vector2i
## Aldeão que reservou (só um por vez). Tipado como Node2D de propósito: usar `Pawn` aqui
## criaria uma dependência circular com pawn.gd, que usa `Gatherable`.
var worker: Node2D

## Alcance (px) da ferramenta do aldeão, do centro dele até onde ela bate.
const TOOL_REACH := 22.0
## Desvio lateral máximo (px) pela frente ou por trás, para não passar para a célula na diagonal.
const MAX_FRONT_SHIFT := 30.0

var _click_shape := RectangleShape2D.new()


func _ready() -> void:
	collision_mask = 0
	# Cada instância precisa do seu próprio shape: o da cena é compartilhado entre todas.
	($CollisionShape2D as CollisionShape2D).shape = _click_shape
	_set_targetable(true)


## Pode receber uma ordem do jogador.
func can_be_targeted() -> bool:
	return can_harvest()


## Tem recurso para tirar agora.
func can_harvest() -> bool:
	return false


## Ponto onde o aldeão trabalha, com a ferramenta encostando no recurso, para quem chega pela
## célula vizinha que contém `from_point`.
func get_work_position(from_point: Vector2) -> Vector2:
	var side := Vector2i((from_point / World.TILE_SIZE).floor()) - cell
	var extent := get_work_extent()
	if side.x != 0:
		return position + Vector2(signi(side.x) * (extent.x + TOOL_REACH), 2)
	# Pela frente ou por trás fica um pouco à esquerda, virado para o recurso: o golpe é lateral.
	var x := -minf(extent.x * 0.7 + TOOL_REACH * 0.8, MAX_FRONT_SHIFT)
	return position + Vector2(x, 20.0 if side.y > 0 else -extent.y * 0.45)


## Tamanho da parte do recurso em que o aldeão bate: (meia largura, altura), em px.
func get_work_extent() -> Vector2:
	return Vector2(14, 44)


## Retira até `_amount` do recurso e devolve quanto foi retirado.
func harvest(_amount: int) -> int:
	return 0


## Base da área clicável nos pés (origem do nó).
func _set_click_size(size: Vector2) -> void:
	_click_shape.size = size
	($CollisionShape2D as CollisionShape2D).position = Vector2(0, -size.y / 2.0)


## Liga/desliga como alvo de ordens: grupo `collectibles` (busca) e camada de física (clique).
func _set_targetable(targetable: bool) -> void:
	if targetable:
		add_to_group(PhysicsLayers.GROUP_COLLECTIBLES)
	else:
		remove_from_group(PhysicsLayers.GROUP_COLLECTIBLES)
	# set_deferred: evita mudar o estado da física no meio de um callback.
	set_deferred("collision_layer", PhysicsLayers.COLLECTIBLES if targetable else 0)


## Tira do mapa de vez. queue_free (e não free): a remoção acontece no fim do frame, com
## segurança dentro de sinais; o nó leva junto sprite, colisão, grupo e tweens.
func _remove_from_map() -> void:
	_set_targetable(false)
	removed.emit(self)
	queue_free()
