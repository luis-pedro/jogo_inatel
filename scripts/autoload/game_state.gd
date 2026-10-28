extends Node
## Estado global da partida: recursos do reino e população.
## Registrado como autoload "GameState" (Project Settings > Globals).

signal resources_changed(resources: Dictionary)
signal population_changed(population: int)

## Cada casa construída gera esta quantidade de aldeões.
const VILLAGERS_PER_HOUSE := 2

## Recursos iniciais (valores provisórios, ajustar no balanceamento).
const STARTING_RESOURCES := {
	"food": 50,
	"gold": 20,
	"wood": 30,
}

var resources: Dictionary = {}
var houses: int = 0
var population: int = 0


func _ready() -> void:
	reset()


## Reinicia o estado para o começo de uma nova partida: 1 casa, 2 aldeões.
func reset() -> void:
	resources = STARTING_RESOURCES.duplicate()
	houses = 0
	population = 0
	add_house()
	resources_changed.emit(resources)


func add_house() -> void:
	houses += 1
	population += VILLAGERS_PER_HOUSE
	population_changed.emit(population)


func add_resource(type: String, amount: int) -> void:
	assert(resources.has(type), "Recurso desconhecido: %s" % type)
	resources[type] += amount
	resources_changed.emit(resources)


func can_afford(cost: Dictionary) -> bool:
	for type in cost:
		if resources.get(type, 0) < cost[type]:
			return false
	return true


## Desconta o custo se houver recursos suficientes. Retorna se conseguiu pagar.
func spend(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for type in cost:
		resources[type] -= cost[type]
	resources_changed.emit(resources)
	return true
