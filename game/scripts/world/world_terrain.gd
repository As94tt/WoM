class_name WorldTerrain
extends StaticBody3D
## Gelände der Startwelt (Ticket #15), mit Godot-Bordmitteln erzeugt:
## ein Raster aus Dreiecken (Rasterweite aus WorldData) mit
## - Höhe: Summe aller Hügel (TerrainHill), in ebenen Gebieten eingeebnet,
##   am Rand Anstieg zum Gebirge,
## - Farbe: Bodenfarbe des Gebiets aus ZoneData (Vertex-Farben), am Rand
##   Bergfarbe aus WorldData.
## Kollision ist ein Dreiecksnetz (ConcavePolygonShape3D) auf der Ebene „Welt“;
## daraus entsteht auch das NavMesh.
##
## Andere Knoten fragen die Höhe mit get_surface_height() ab (z. B. Bäume,
## Platzhalter). Das Gelände wird beim ersten Zugriff erzeugt, deshalb ist die
## Reihenfolge von _ready() egal. Alle Spieler erzeugen dasselbe Gelände aus
## denselben Daten; nichts davon wird übertragen.

const GROUP := &"world_terrain"

## Weltdaten (Größe, Rand, Farben).
@export var world_data: WorldData

var _built := false
var _hills: Array[TerrainHill] = []
var _zones: Array[WorldZone] = []
var _flat_zones: Array[WorldZone] = []
## Höhen der Rasterpunkte, Zeile für Zeile (z), je Zeile _points_per_side Werte (x).
var _heights := PackedFloat32Array()
var _points_per_side := 0
var _origin := 0.0
var _cell := 4.0


## Das Gelände der aktuellen Szene oder null.
static func find_in(tree: SceneTree) -> WorldTerrain:
	return tree.get_first_node_in_group(GROUP) as WorldTerrain


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	_ensure_built()


## Höhe der Geländeoberfläche (genau wie Mesh und Kollision) an (x, z).
func get_surface_height(x: float, z: float) -> float:
	_ensure_built()
	var fx := clampf((x - _origin) / _cell, 0.0, _points_per_side - 1.001)
	var fz := clampf((z - _origin) / _cell, 0.0, _points_per_side - 1.001)
	var i := int(fx)
	var j := int(fz)
	fx -= i
	fz -= j
	var a := _height_at_index(i, j)
	var b := _height_at_index(i + 1, j)
	var c := _height_at_index(i + 1, j + 1)
	var d := _height_at_index(i, j + 1)
	# Gleiche Dreiecksteilung wie im Mesh: (a, b, c) und (a, c, d).
	if fx >= fz:
		return a + fx * (b - a) + fz * (c - b)
	return a + fz * (d - a) + fx * (c - d)


## Gebiet an der Stelle (x, z) oder null. Bei Überschneidung gewinnt das kleinere.
func get_zone_at(x: float, z: float) -> WorldZone:
	_ensure_built()
	var best: WorldZone = null
	var best_area := INF
	for zone in _zones:
		var rect := zone.get_rect()
		if rect.has_point(Vector2(x, z)) and rect.get_area() < best_area:
			best = zone
			best_area = rect.get_area()
	return best


## Berechnete Höhe ohne Raster (Hügel, Einebnung, Rand).
func _compute_height(x: float, z: float) -> float:
	var h := 0.0
	for hill in _hills:
		h += hill.height_at(x, z)
	var flat := 0.0
	for zone in _flat_zones:
		flat = maxf(flat, _flatten_weight(zone.get_rect(), x, z))
		if flat >= 1.0:
			break
	h *= 1.0 - flat
	var edge := maxf(absf(x), absf(z))
	var start := world_data.playable_half_extent
	h += world_data.border_height * smoothstep(start, start + world_data.border_width, edge)
	return h


## 1 innerhalb des Rechtecks, fällt bis flatten_margin außerhalb auf 0.
func _flatten_weight(rect: Rect2, x: float, z: float) -> float:
	var dx := maxf(maxf(rect.position.x - x, x - rect.end.x), 0.0)
	var dz := maxf(maxf(rect.position.y - z, z - rect.end.y), 0.0)
	var d := sqrt(dx * dx + dz * dz)
	return 1.0 - smoothstep(0.0, world_data.flatten_margin, d)


func _height_at_index(i: int, j: int) -> float:
	return _heights[j * _points_per_side + i]


func _ground_color(x: float, z: float) -> Color:
	var zone := get_zone_at(x, z)
	var color := zone.data.ground_color if zone != null and zone.data != null \
			else world_data.fallback_ground_color
	var edge := maxf(absf(x), absf(z))
	var start := world_data.playable_half_extent
	var t := smoothstep(start, start + world_data.border_width * 0.5, edge)
	return color.lerp(world_data.mountain_ground_color, t)


func _ensure_built() -> void:
	if _built:
		return
	_built = true
	if world_data == null:
		push_error("WorldTerrain: world_data fehlt.")
		world_data = WorldData.new()
	_collect_sources()
	_cell = world_data.terrain_cell_size
	_origin = -world_data.terrain_half_extent
	_points_per_side = int(ceil(2.0 * world_data.terrain_half_extent / _cell)) + 1
	_heights.resize(_points_per_side * _points_per_side)
	for j in _points_per_side:
		var z := _origin + j * _cell
		for i in _points_per_side:
			_heights[j * _points_per_side + i] = _compute_height(_origin + i * _cell, z)
	_build_mesh()


func _collect_sources() -> void:
	var tree := get_tree()
	for node in tree.get_nodes_in_group(TerrainHill.GROUP):
		_hills.append(node as TerrainHill)
	for node in tree.get_nodes_in_group(WorldZone.GROUP):
		var zone := node as WorldZone
		_zones.append(zone)
		if zone.flat_ground:
			_flat_zones.append(zone)


func _build_mesh() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in _points_per_side:
		var z := _origin + j * _cell
		for i in _points_per_side:
			var x := _origin + i * _cell
			st.set_color(_ground_color(x, z))
			st.add_vertex(Vector3(x, _height_at_index(i, j), z))
	for j in _points_per_side - 1:
		for i in _points_per_side - 1:
			var a := j * _points_per_side + i
			var b := a + 1
			var d := a + _points_per_side
			var c := d + 1
			# Von oben gesehen im Uhrzeigersinn (Godot: Vorderseite).
			st.add_index(a)
			st.add_index(b)
			st.add_index(c)
			st.add_index(a)
			st.add_index(c)
			st.add_index(d)
	st.generate_normals()
	var mesh := st.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	mesh.surface_set_material(0, material)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	mesh_instance.mesh = mesh
	add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = mesh.create_trimesh_shape()
	add_child(collision)
