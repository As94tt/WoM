class_name TeleportPoint
extends Marker3D
## Besonderer Punkt für den Teleport im Entwickler-Panel (Ticket #15), z. B.
## „Banditenlager“ oder „Boss-Eingang“. Liegt in der Unterszene eines Gebiets.
## Die Figur blickt nach dem Teleport in Richtung -Z des Markers.

const GROUP := &"teleport_points"

## Beschriftung im Entwickler-Panel.
@export var display_name: String
## Reihenfolge in der Liste (aufsteigend).
@export var order: int = 0


func _enter_tree() -> void:
	add_to_group(GROUP)
