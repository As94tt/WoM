class_name EnemySpawnArea
extends Marker3D
## Spawnbereich für Gegner (Ticket #36). Liegt in der Unterszene eines
## Gebiets und verweist auf eine Spawngruppe (spawngruppen.csv: Gegnertypen
## mit Gewichtung, Anzahl, Stufen, Respawnzeit, seltene Gegner). Der Bereich
## selbst bestimmt nur den Ort:
##
## - Radius (radius > 0): Gegner erscheinen an zufälligen Stellen im Kreis,
##   auf begehbarem Boden (NavMesh, sonst Geländehöhe). Anzahl aus der Gruppe.
## - Feste Punkte (Marker3D-Kinder): Je Punkt steht ein Gegner (z. B. Wachen,
##   Boss); die Anzahl der Gruppe gilt dann nicht. Er blickt in Richtung -Z
##   des Punkts.
## - Weder Radius noch Punkte: ein Gegner genau an diesem Knoten.
##
## Die Gegner erzeugt und verwaltet der Host (EnemySpawnManager). Für das
## Entwickler-Panel kann der Bereich seinen Umriss am Boden zeigen
## (set_debug_visible): Kreis bzw. Punkte und eine Beschriftung, die der
## Manager mit den Respawnzeiten füllt.

const GROUP := &"enemy_spawn_areas"
## Graubox der Anzeige: Farbe der Platzhalter „Spawn“ bzw. „Boss“ (Daten).
const SPAWN_KIND: PlaceholderKind = preload("res://data/world/placeholders/spawn.tres")
const BOSS_KIND: PlaceholderKind = preload("res://data/world/placeholders/boss.tres")
const DEBUG_ALPHA := 0.3
const DEBUG_POINT_RADIUS := 0.8
const DEBUG_LABEL_HEIGHT := 3.5
const DEBUG_LABEL_PIXEL := 0.016

## ID in spawngruppen.csv.
@export var spawn_group: StringName
## Radius in Metern; 0 = feste Punkte (Marker3D-Kinder) bzw. dieser Punkt.
@export_range(0.0, 100.0, 0.5) var radius := 6.0

var _debug: Node3D = null
var _debug_label: Label3D = null


func _enter_tree() -> void:
	add_to_group(GROUP)


## Zeile der Spawngruppe oder null.
func get_group_row() -> TableRow:
	return Data.spawngruppe(spawn_group)


## Feste Punkte (Marker3D-Kinder) in Reihenfolge; leer = Radius.
func get_fixed_points() -> Array[Marker3D]:
	var result: Array[Marker3D] = []
	for child in get_children():
		if child is Marker3D:
			result.append(child)
	return result


## true, wenn der Bereich feste Punkte nutzt (Kinder oder kein Radius).
func uses_fixed_points() -> bool:
	return not get_fixed_points().is_empty() or radius <= 0.0


## Anzahl gleichzeitiger Gegner (ohne zusätzlichen seltenen Gegner): je
## festem Punkt einer, sonst „anzahl“ der Gruppe.
func get_slot_count() -> int:
	var points := get_fixed_points()
	if not points.is_empty():
		return points.size()
	if radius <= 0.0:
		return 1
	var row := get_group_row()
	return maxi(1, int(row.get_value("anzahl", 1))) if row != null else 0


## Stelle für Platz index (feste Punkte) bzw. ein zufälliger Punkt im Kreis
## (waagerecht, Höhe dieses Knotens; der Manager setzt ihn auf den Boden).
func get_spawn_point(index: int, rng: RandomNumberGenerator) -> Transform3D:
	var points := get_fixed_points()
	if not points.is_empty():
		var marker := points[index % points.size()]
		return _upright(marker.global_transform)
	if radius <= 0.0:
		return _upright(global_transform)
	# Gleichverteilt in der Kreisfläche, Blickrichtung zufällig.
	var angle := rng.randf() * TAU
	var distance := sqrt(rng.randf()) * radius
	var origin := global_position + Vector3(cos(angle), 0.0, sin(angle)) * distance
	return Transform3D(Basis(Vector3.UP, rng.randf() * TAU), origin)


# --- Entwickler-Panel --------------------------------------------------------

## Umriss am Boden zeigen bzw. verbergen (beim ersten Zeigen erzeugt).
func set_debug_visible(on: bool) -> void:
	if on and _debug == null:
		_debug = _create_debug()
		add_child(_debug)
	if _debug != null:
		_debug.visible = on


func is_debug_visible() -> bool:
	return _debug != null and _debug.visible


## Text der Beschriftung über dem Bereich (Gruppe, Respawnzeiten).
func set_debug_text(text: String) -> void:
	if _debug_label != null:
		_debug_label.text = text


func _create_debug() -> Node3D:
	var root := Node3D.new()
	root.name = "DebugArea"
	var boss := false
	var row := get_group_row()
	if row != null:
		for id: String in (row.get_value("gegner", {}) as Dictionary):
			var enemy := Data.gegner(StringName(id))
			if enemy != null and String(enemy.get_value("rang", "")) == "boss":
				boss = true
	var color := (BOSS_KIND if boss else SPAWN_KIND).color
	color.a = DEBUG_ALPHA
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	var points := get_fixed_points()
	if points.is_empty():
		_add_disc(root, Vector3.ZERO, maxf(radius, DEBUG_POINT_RADIUS), material)
	else:
		for point in points:
			_add_disc(root, point.position, DEBUG_POINT_RADIUS, material)
	_debug_label = Label3D.new()
	_debug_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_debug_label.pixel_size = DEBUG_LABEL_PIXEL
	_debug_label.no_depth_test = true
	_debug_label.layers = 1 << (WorldZone.DEV_RENDER_LAYER - 1)
	_debug_label.position = Vector3.UP * DEBUG_LABEL_HEIGHT
	_debug_label.text = String(spawn_group)
	root.add_child(_debug_label)
	return root


func _add_disc(root: Node3D, at: Vector3, disc_radius: float, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = disc_radius
	mesh.bottom_radius = disc_radius
	mesh.height = 0.05
	mesh.radial_segments = 48
	mesh.rings = 1
	mesh.material = material
	var disc := MeshInstance3D.new()
	disc.mesh = mesh
	disc.layers = 1 << (WorldZone.DEV_RENDER_LAYER - 1)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disc.position = at + Vector3.UP * 0.12
	root.add_child(disc)


static func _upright(t: Transform3D) -> Transform3D:
	var forward := -t.basis.z
	return Transform3D(Basis(Vector3.UP, atan2(-forward.x, -forward.z)), t.origin)
