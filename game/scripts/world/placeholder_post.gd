class_name PlaceholderPost
extends Node3D
## Platzhalter-Pfahl mit Beschriftung (Ticket #15), z. B. „NPC: Händlerin“ oder
## „Spawn: Junge Wölfe“. Markiert Inhalte, deren System noch nicht umgesetzt
## ist; spätere Tickets ersetzen die Pfähle durch echte NPCs, Puppen und
## Gegner. Spawnbereiche tragen die ID ihrer Spawngruppe als Text
## (spawn_group_id); ob sie in eine Tabelle wandert, klärt #39.
##
## Sichtbar nur im Entwicklungsmodus (Debug-Build), ein- und ausblendbar im
## Entwickler-Panel. Pfähle haben keine Kollision und liegen auf der
## Sichtbarkeitsebene „Entwicklung“, damit sie nicht im Kartenbild erscheinen.

const GROUP := &"dev_placeholders"

## Art des Platzhalters (Farbe und Vorsilbe), aus res://data/world/placeholders/.
@export var kind: PlaceholderKind
## Beschriftung, z. B. „Händlerin“ oder „Junge Wölfe (1–3), Rudel“.
@export var text: String
## Spawngruppe dieses Spawnbereichs (nur bei Spawns), z. B. &"wolfswiese_junge_woelfe".
@export var spawn_group_id: StringName
## Radius des Bereichs in Metern (Spawnbereich, Fläche); 0 = nur der Pfahl.
@export var area_radius: float = 0.0
## Beim Start auf die Geländehöhe setzen.
@export var snap_to_ground := true


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	visible = OS.is_debug_build()
	if snap_to_ground:
		GroundSnap.snap(self)
	%Label.text = get_label_text()
	if kind != null:
		var material := StandardMaterial3D.new()
		material.albedo_color = kind.color
		%Pole.material_override = material
		if area_radius > 0.0:
			_add_area(kind.color)


## Beschriftung wie im Spiel angezeigt, z. B. „Spawn: Junge Wölfe“.
func get_label_text() -> String:
	var label := "%s: %s" % [kind.prefix, text] if kind != null else text
	if spawn_group_id != &"":
		label += "\nSpawngruppe: %s" % spawn_group_id
	return label


func _add_area(color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = area_radius
	mesh.bottom_radius = area_radius
	mesh.height = 0.05
	mesh.radial_segments = 32
	mesh.rings = 1
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	color.a = 0.25
	material.albedo_color = color
	mesh.material = material
	var area := MeshInstance3D.new()
	area.name = "Area"
	area.mesh = mesh
	area.layers = %Pole.layers
	area.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	area.position.y = 0.15
	add_child(area)
