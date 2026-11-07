class_name MountainRing
extends Node3D
## Berge am Rand der Startwelt (Ticket #15): viele Kegel in einem Band um die
## spielbare Fläche, zufällig, aber immer gleich (fester seed). Reine Optik;
## nicht passierbar machen den Rand der Geländeanstieg und die unsichtbaren
## Wände (Ebene „Unsichtbare Wände“). Ein MultiMesh, ein Zeichenaufruf.

## Kegel-Mesh (Ursprung in der Mitte, Höhe 1 m, Grundradius 1 m).
@export var mesh: Mesh
## Abstand der Kegelmitten von der Weltmitte (größte Achse), von–bis in Metern.
@export var band := Vector2(298, 336)
## Anzahl der Kegel.
@export var count: int = 90
## Höhe von–bis in Metern.
@export var height_range := Vector2(40, 90)
## Grundradius von–bis in Metern.
@export var radius_range := Vector2(22, 40)
## Zufallsstartwert.
@export var seed_value: int = 7


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = count
	var terrain := WorldTerrain.find_in(get_tree())
	for i in count:
		# Gleichmäßig über die vier Seiten des Quadrats verteilen.
		var t := (float(i) + rng.randf()) / count * 4.0
		var side := int(t)
		var along := (t - side) * 2.0 - 1.0
		var dist := rng.randf_range(band.x, band.y)
		var pos2 := Vector2(along * band.y, -dist)
		pos2 = pos2.rotated(side * PI / 2.0)
		var height := rng.randf_range(height_range.x, height_range.y)
		var radius := rng.randf_range(radius_range.x, radius_range.y)
		# Fuß des Kegels auf die tiefste Stelle unter ihm setzen (zur Weltmitte
		# hin fällt das Gelände ab), damit er nirgends schwebt.
		var inner := pos2 + Vector2(0.0, 1.0).rotated(side * PI / 2.0) * radius
		var ground := 0.0
		if terrain != null:
			ground = minf(terrain.get_surface_height(pos2.x, pos2.y),
					terrain.get_surface_height(inner.x, inner.y))
		var basis := Basis.from_scale(Vector3(radius, height, radius)) \
				.rotated(Vector3.UP, rng.randf() * TAU)
		multimesh.set_instance_transform(i, Transform3D(basis,
				Vector3(pos2.x, ground + height / 2.0 - 1.0, pos2.y)))
	var instance := MultiMeshInstance3D.new()
	instance.name = "Mountains"
	instance.multimesh = multimesh
	instance.top_level = true
	# Berge werfen keine Schatten, sonst lägen Dorf und Parcours am Südrand im Schatten.
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	instance.global_transform = Transform3D.IDENTITY
