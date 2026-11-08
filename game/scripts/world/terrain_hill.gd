class_name TerrainHill
extends Marker3D
## Ein sanfter Hügel (oder mit negativer Höhe eine Mulde, z. B. für den See)
## im Gelände der Startwelt (Ticket #15). Kann in jeder Unterszene eines
## Gebiets liegen; WorldTerrain sammelt alle Hügel über die Gruppe GROUP.
## Form: Glockenkurve um den Mittelpunkt, ab etwa 3 × radius ohne Wirkung.

const GROUP := &"terrain_hills"

## Höhe in der Mitte in Metern (negativ = Mulde).
@export var height: float = 5.0
## Breite des Hügels in Metern (Abstand, bei dem noch ca. 37 % der Höhe erreicht sind).
@export var radius: float = 30.0


func _enter_tree() -> void:
	add_to_group(GROUP)


## Höhenbeitrag dieses Hügels an der Stelle (x, z) in Weltkoordinaten.
func height_at(x: float, z: float) -> float:
	var center := global_position
	var d2 := (x - center.x) * (x - center.x) + (z - center.z) * (z - center.z)
	var r2 := radius * radius
	if d2 > 9.0 * r2:
		return 0.0
	return height * exp(-d2 / r2)
