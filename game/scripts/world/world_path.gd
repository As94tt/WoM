class_name WorldPath
extends Node3D
## Ein Weg in der Startwelt (Ticket #15): ein flaches Band auf dem Gelände
## entlang der Punkte in points (Weltkoordinaten, y wird ignoriert), zwischen
## den Punkten weich gerundet. Reine Optik ohne Kollision; Gelände abseits der
## Wege bleibt begehbar. Farbe aus WorldData.path_color.
## Der Wald (ForestScatter) hält über die Gruppe GROUP Abstand zu Wegen.

const GROUP := &"world_paths"
## Abstand der Stützpunkte entlang des Wegs, in Metern.
const SAMPLE_DISTANCE := 2.0
## Wie weit das Band über dem Gelände liegt (gegen Flimmern).
const LIFT := 0.08

## Weltdaten (für die Wegfarbe).
@export var world_data: WorldData
## Breite des Wegs in Metern.
@export var width: float = 6.0
## Eckpunkte des Wegs in Weltkoordinaten.
@export var points: PackedVector3Array

var _samples := PackedVector2Array()
var _bounds := Rect2()


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	_build_mesh()


## Punkte entlang des Wegs (Welt-XZ), alle SAMPLE_DISTANCE Meter.
func get_samples() -> PackedVector2Array:
	if _samples.is_empty():
		_samples = _sample()
		if not _samples.is_empty():
			_bounds = Rect2(_samples[0], Vector2.ZERO)
			for p in _samples:
				_bounds = _bounds.expand(p)
	return _samples


## Kleinster Abstand von (x, z) zur Wegmitte. Liegt der Punkt weiter als
## max_distance vom Weg entfernt, kann statt des genauen Werts INF kommen.
func distance_to(x: float, z: float, max_distance := INF) -> float:
	var p := Vector2(x, z)
	var samples := get_samples()
	if max_distance < INF and not _bounds.grow(max_distance).has_point(p):
		return INF
	var best := INF
	for i in samples.size() - 1:
		var q := Geometry2D.get_closest_point_to_segment(p, samples[i], samples[i + 1])
		best = minf(best, p.distance_to(q))
	return best


func _sample() -> PackedVector2Array:
	var result := PackedVector2Array()
	var pts: Array[Vector2] = []
	for p in points:
		pts.append(Vector2(p.x, p.z))
	if pts.size() < 2:
		return result
	for i in pts.size() - 1:
		var p0 := pts[maxi(i - 1, 0)]
		var p1 := pts[i]
		var p2 := pts[i + 1]
		var p3 := pts[mini(i + 2, pts.size() - 1)]
		var steps := maxi(1, int(ceil(p1.distance_to(p2) / SAMPLE_DISTANCE)))
		for s in steps:
			result.append(_catmull_rom(p0, p1, p2, p3, float(s) / steps))
	result.append(pts[pts.size() - 1])
	return result


static func _catmull_rom(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 \
			+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


func _build_mesh() -> void:
	var samples := get_samples()
	if samples.size() < 2:
		return
	if world_data == null:
		push_error("WorldPath %s: world_data fehlt." % name)
		return
	var terrain := WorldTerrain.find_in(get_tree())
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var half := width / 2.0
	for i in samples.size():
		var prev := samples[maxi(i - 1, 0)]
		var next := samples[mini(i + 1, samples.size() - 1)]
		var dir := (next - prev).normalized()
		var side := Vector2(-dir.y, dir.x) * half
		for p: Vector2 in [samples[i] - side, samples[i] + side]:
			var h := terrain.get_surface_height(p.x, p.y) if terrain != null else 0.0
			# Mittelhöhe dazunehmen, damit das Band in Senken nicht einsinkt.
			if terrain != null:
				h = maxf(h, terrain.get_surface_height(samples[i].x, samples[i].y))
			st.add_vertex(Vector3(p.x, h + LIFT, p.y))
	for i in samples.size() - 1:
		var l0 := i * 2
		var r0 := l0 + 1
		var l1 := l0 + 2
		var r1 := l0 + 3
		# Von oben gesehen im Uhrzeigersinn (Godot: Vorderseite).
		st.add_index(l0)
		st.add_index(l1)
		st.add_index(r1)
		st.add_index(l0)
		st.add_index(r1)
		st.add_index(r0)
	var mesh := st.commit()
	var material := StandardMaterial3D.new()
	material.albedo_color = world_data.path_color
	mesh.surface_set_material(0, material)
	var instance := MeshInstance3D.new()
	instance.name = "Mesh"
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Mesh liegt in Weltkoordinaten.
	instance.top_level = true
	add_child(instance)
	instance.global_transform = Transform3D.IDENTITY
