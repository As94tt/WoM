class_name UnitSpawnPoint
extends Marker3D
## Aufstellpunkt für eine Einheit (Ticket #31), z. B. eine Übungspuppe im
## Trainingsbereich. Liegt in der Unterszene eines Gebiets; der Host erzeugt
## beim Laden der Welt an jedem Punkt die Einheit (GameWorld, UnitSpawner),
## die Spawner überträgt sie an alle Mitspieler. Die Einheit blickt in
## Richtung -Z des Markers und steht auf der Geländehöhe.
##
## Gegner (#36) bekommen eigene Spawnbereiche; dieser Punkt ist für einzelne,
## fest aufgestellte Einheiten gedacht.

const GROUP := &"unit_spawn_points"

## Welche Art Einheit hier steht.
enum Kind { TRAINING_DUMMY }

@export var kind: Kind = Kind.TRAINING_DUMMY
## Kennung in der Tabelle der Art (Übungspuppe: id in uebungspuppen.csv).
@export var unit_id: StringName


func _enter_tree() -> void:
	add_to_group(GROUP)


## Lage der Einheit: Position auf der Geländehöhe, Drehung um die Hochachse.
func get_spawn_transform() -> Transform3D:
	var t := global_transform
	var terrain := WorldTerrain.find_in(get_tree())
	if terrain != null:
		t.origin.y = terrain.get_surface_height(t.origin.x, t.origin.z)
	var forward := -t.basis.z
	return Transform3D(Basis(Vector3.UP, atan2(-forward.x, -forward.z)), t.origin)
