class_name GroundSnap
extends Node3D
## Setzt den Knoten beim Start auf die Höhe des Geländes (Ticket #15), z. B. für
## Gegenstände auf Hügeln (großer Baum auf der Wolfswiese). Ohne Gelände
## (Szene einzeln geöffnet) bleibt die Höhe unverändert.

## Zusätzlicher Versatz nach oben (negativ = etwas einsinken lassen).
@export var height_offset: float = 0.0


func _ready() -> void:
	snap(self, height_offset)


## Setzt node auf die Geländehöhe an seiner Position.
static func snap(node: Node3D, offset := 0.0) -> void:
	var terrain := WorldTerrain.find_in(node.get_tree())
	if terrain == null:
		return
	var p := node.global_position
	node.global_position = Vector3(p.x, terrain.get_surface_height(p.x, p.z) + offset, p.z)
