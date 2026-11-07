class_name WorldSpawnPoint
extends Marker3D
## Start- oder Wiedereinstiegspunkt für Spielfiguren (Ticket #15). Liegt in der
## Unterszene eines Gebiets. Die Blickrichtung der Figur ist -Z des Markers.
## GameWorld sucht die Punkte über die Gruppen START_GROUP und RESPAWN_GROUP.
## Der Host setzt neue Figuren an den Startpunkt; nach dem Tod (M3) kehrt eine
## Figur zum nächsten Wiedereinstiegspunkt zurück (GameWorld.respawn_player).

const START_GROUP := &"player_start_points"
const RESPAWN_GROUP := &"respawn_points"

## Anzeigename, z. B. für die Karte („Wiedereinstieg: Startdorf“).
@export var display_name: String
## Neue Spielfiguren erscheinen hier.
@export var is_start := false
## Wiedereinstiegspunkt nach dem Tod; erscheint als Symbol auf der Karte.
@export var is_respawn := false


func _enter_tree() -> void:
	if is_start:
		add_to_group(START_GROUP)
	if is_respawn:
		add_to_group(RESPAWN_GROUP)
