class_name ForestScatter
extends Node3D
## Verteilt viele einfache Bäume (Stamm-Zylinder mit Kugelkrone) zufällig, aber
## immer gleich (fester seed), in einem Rechteck um diesen Knoten (Ticket #15).
## Bäume halten Abstand zu Wegen (WorldPath) und zu Lichtungen (Kinder vom
## Typ ForestClearing).
##
## Darstellung über MultiMesh (zwei Zeichenaufrufe für alle Bäume). Jeder Baum
## hat Kollision auf der Ebene „Welt“: der Stamm blockiert Bewegung, Sichtlinie
## und Wegfindung (NavMesh), die Krone die Kamera. Alle Spieler erzeugen
## denselben Wald aus denselben Werten; nichts wird übertragen.

## Größe des Bereichs (x, z) in Metern, mittig um diesen Knoten.
@export var area_size := Vector2(100, 100)
## Anzahl der Versuche, einen Baum zu setzen (zu nahe Bäume werden verworfen).
@export var tree_count: int = 500
## Mindestabstand zwischen Stämmen in Metern.
@export var min_spacing: float = 4.0
## Abstand zum Rand eines Wegs in Metern.
@export var path_clearance: float = 3.0
## Zufallsstartwert; gleicher Wert = gleicher Wald.
@export var seed_value: int = 15
## Kleinste und größte Skalierung eines Baums.
@export var scale_range := Vector2(0.8, 1.3)
## Mesh des Stamms (Ursprung in der Mitte, Höhe trunk_height).
@export var trunk_mesh: Mesh
## Mesh der Krone (Ursprung in der Mitte).
@export var crown_mesh: Mesh
## Stammhöhe in Metern bei Skalierung 1.
@export var trunk_height: float = 6.0
## Stammradius in Metern bei Skalierung 1 (für die Kollision).
@export var trunk_radius: float = 0.5
## Kronenradius in Metern bei Skalierung 1 (für die Kollision).
@export var crown_radius: float = 3.0
## Höhe der Kronenmitte über dem Boden bei Skalierung 1.
@export var crown_height: float = 7.5

var _positions: Array[Vector3] = []
var _scales: Array[float] = []


func _ready() -> void:
	_place_trees()
	_build_visuals()
	_build_collision()


## Anzahl der tatsächlich gesetzten Bäume.
func get_tree_count() -> int:
	return _positions.size()


func _place_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var terrain := WorldTerrain.find_in(get_tree())
	var paths: Array[WorldPath] = []
	for node in get_tree().get_nodes_in_group(WorldPath.GROUP):
		paths.append(node as WorldPath)
	var clearings: Array[ForestClearing] = []
	for child in get_children():
		if child is ForestClearing:
			clearings.append(child)
	# Raster für die Abstandsprüfung (Zellgröße = Mindestabstand).
	var grid := {}
	var origin := global_position
	for n in tree_count:
		var x := origin.x + rng.randf_range(-area_size.x / 2.0, area_size.x / 2.0)
		var z := origin.z + rng.randf_range(-area_size.y / 2.0, area_size.y / 2.0)
		var tree_scale := rng.randf_range(scale_range.x, scale_range.y)
		if not _is_free(x, z, grid, paths, clearings):
			continue
		var cell := Vector2i(floori(x / min_spacing), floori(z / min_spacing))
		grid[cell] = Vector2(x, z)
		var y := terrain.get_surface_height(x, z) if terrain != null else origin.y
		_positions.append(Vector3(x, y, z))
		_scales.append(tree_scale)


func _is_free(x: float, z: float, grid: Dictionary, paths: Array[WorldPath],
		clearings: Array[ForestClearing]) -> bool:
	var cell := Vector2i(floori(x / min_spacing), floori(z / min_spacing))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var other: Variant = grid.get(cell + Vector2i(dx, dz))
			if other != null and (other as Vector2).distance_to(Vector2(x, z)) < min_spacing:
				return false
	for clearing in clearings:
		var c := clearing.global_position
		if Vector2(c.x, c.z).distance_to(Vector2(x, z)) < clearing.radius:
			return false
	for path in paths:
		var clearance := path.width / 2.0 + path_clearance
		if path.distance_to(x, z, clearance) < clearance:
			return false
	return true


func _build_visuals() -> void:
	var trunk_transforms: Array[Transform3D] = []
	var crown_transforms: Array[Transform3D] = []
	for i in _positions.size():
		var s := _scales[i]
		var basis := Basis.from_scale(Vector3.ONE * s)
		var foot := _positions[i]
		trunk_transforms.append(Transform3D(basis, foot + Vector3.UP * trunk_height * s / 2.0))
		crown_transforms.append(Transform3D(basis, foot + Vector3.UP * crown_height * s))
	add_child(_multimesh_instance("Trunks", trunk_mesh, trunk_transforms))
	add_child(_multimesh_instance("Crowns", crown_mesh, crown_transforms))


func _multimesh_instance(node_name: String, mesh: Mesh, transforms: Array[Transform3D]) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	# Transformationen sind Weltkoordinaten.
	instance.top_level = true
	return instance


func _build_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = 1
	body.collision_mask = 0
	body.top_level = true
	add_child(body)
	body.global_transform = Transform3D.IDENTITY
	# Gemeinsame Formen je Skalierungsstufe wären sparsamer; bei einigen hundert
	# Bäumen reicht eine Form pro Baum.
	for i in _positions.size():
		var s := _scales[i]
		var trunk := CylinderShape3D.new()
		trunk.radius = trunk_radius * s
		trunk.height = trunk_height * s
		var trunk_node := CollisionShape3D.new()
		trunk_node.shape = trunk
		trunk_node.position = _positions[i] + Vector3.UP * trunk_height * s / 2.0
		body.add_child(trunk_node)
		var crown := SphereShape3D.new()
		crown.radius = crown_radius * s
		var crown_node := CollisionShape3D.new()
		crown_node.shape = crown
		crown_node.position = _positions[i] + Vector3.UP * crown_height * s
		body.add_child(crown_node)
