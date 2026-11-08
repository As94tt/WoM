class_name WorldZone
extends Node3D
## Wurzel der Unterszene eines Gebiets (Ticket #15), z. B. dorf.tscn.
## Jede Unterszene enthält:
## - ein Area3D „Bounds“ mit einer BoxShape3D als Gebietsgrenze (unsichtbar),
##   die erkennt, welche Spielfiguren im Gebiet sind (siehe ZoneTracker),
## - den Inhalt des Gebiets (Gebäude, Platzhalter, Teleport- und
##   Wiedereinstiegspunkte, Hügel) in Koordinaten relativ zur Gebietsmitte.
## Die Bodenfarbe kommt aus den Gebietsdaten (ZoneData) und wird vom Gelände
## (WorldTerrain) übernommen. Optional legt ein Marker3D „MapLabel“ fest, wo
## der Gebietsname auf der Karte steht (sonst Mitte der Grenze).
## Mehrere Tickets können so gleichzeitig an verschiedenen Gebieten arbeiten.

const GROUP := &"world_zones"
## Sichtbarkeitsebene für Entwicklungshilfen (nicht im Kartenbild).
const DEV_RENDER_LAYER := 2
## Höhe der Grenzanzeige im Entwicklungsmodus, in Metern.
const DEBUG_WALL_HEIGHT := 30.0
## Deckkraft der Grenzanzeige (Farbe selbst kommt aus ZoneData).
const DEBUG_WALL_ALPHA := 0.3

## Gebietsdaten (Name, Stufenbereich, Bodenfarbe).
@export var data: ZoneData
## Ebener Boden: Hügel werden in diesem Gebiet eingeebnet (Dorf, Lager …),
## damit Gebäude und Platzhalter auf Höhe 0 stehen können.
@export var flat_ground := false

var _debug_bounds: Node3D = null


func _enter_tree() -> void:
	add_to_group(GROUP)


## Das Area3D der Gebietsgrenze.
func get_bounds() -> Area3D:
	return $Bounds


## Gebietsgrenze als Rechteck in Welt-XZ (x → x, y → z).
func get_rect() -> Rect2:
	var shape_node: CollisionShape3D = $Bounds/Shape
	var box := shape_node.shape as BoxShape3D
	var center := shape_node.global_position
	var size := Vector2(box.size.x, box.size.z)
	return Rect2(Vector2(center.x, center.z) - size / 2.0, size)


func contains_point(x: float, z: float) -> bool:
	return get_rect().has_point(Vector2(x, z))


## Wo der Gebietsname auf der Karte steht (Welt-XZ).
func get_map_label_position() -> Vector2:
	var marker := get_node_or_null(^"MapLabel") as Node3D
	if marker != null:
		return Vector2(marker.global_position.x, marker.global_position.z)
	return get_rect().get_center()


func get_display_name() -> String:
	return data.display_name if data != null else String(name)


## Gebietsgrenze sichtbar machen (Entwickler-Panel). Die Anzeige wird beim
## ersten Einschalten erzeugt.
func set_bounds_visible(on: bool) -> void:
	if on and _debug_bounds == null:
		_debug_bounds = _create_debug_bounds()
		add_child(_debug_bounds)
	if _debug_bounds != null:
		_debug_bounds.visible = on


## Vier halbdurchsichtige Wände entlang der Grenze plus Name in der Mitte.
func _create_debug_bounds() -> Node3D:
	var root := Node3D.new()
	root.name = "DebugBounds"
	var rect := get_rect()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var color := data.ground_color if data != null else Color.WHITE
	color.a = DEBUG_WALL_ALPHA
	material.albedo_color = color
	# Die Anzeige wird Kind dieses Knotens; Gebiete sind nicht gedreht.
	var origin := Vector2(global_position.x, global_position.z)
	var c := rect.get_center() - origin
	rect.position -= origin
	var walls := [
		[Vector2(c.x, rect.position.y), Vector3(rect.size.x, DEBUG_WALL_HEIGHT, 0.2)],
		[Vector2(c.x, rect.end.y), Vector3(rect.size.x, DEBUG_WALL_HEIGHT, 0.2)],
		[Vector2(rect.position.x, c.y), Vector3(0.2, DEBUG_WALL_HEIGHT, rect.size.y)],
		[Vector2(rect.end.x, c.y), Vector3(0.2, DEBUG_WALL_HEIGHT, rect.size.y)],
	]
	for wall: Array in walls:
		var mesh := BoxMesh.new()
		mesh.size = wall[1]
		mesh.material = material
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.layers = 1 << (DEV_RENDER_LAYER - 1)
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(instance)
		var pos: Vector2 = wall[0]
		instance.position = Vector3(pos.x, DEBUG_WALL_HEIGHT / 2.0 - 5.0, pos.y)
	var label := Label3D.new()
	label.text = get_display_name()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.05
	label.layers = 1 << (DEV_RENDER_LAYER - 1)
	root.add_child(label)
	label.position = Vector3(c.x, 20.0, c.y)
	return root
