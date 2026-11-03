class_name PhysicsLayers
extends RefCounted
## Máscaras de bits das camadas de física 2D (nomes definidos em Project Settings > Layer Names).
## Uso: `collision_layer = PhysicsLayers.ENEMIES`; `collision_mask = PhysicsLayers.UNITS | PhysicsLayers.BUILDINGS`.
## Ao mudar um nome/ordem, altere também o project.godot.

const UNITS := 1 << 0        # camada 1: pawn, guerreiro, arqueiro...
const ENEMIES := 1 << 1      # camada 2
const BUILDINGS := 1 << 2    # camada 3
const COLLECTIBLES := 1 << 3 # camada 4: árvores, ouro, carne...
const TERRAIN := 1 << 4      # camada 5: água, penhascos
const PROJECTILES := 1 << 5  # camada 6: flechas

## Grupos de nós (para achar tipos sem depender da hierarquia, que é usada pelo y-sort).
const GROUP_UNITS := &"units"
const GROUP_ENEMIES := &"enemies"
const GROUP_BUILDINGS := &"buildings"
const GROUP_COLLECTIBLES := &"collectibles"
