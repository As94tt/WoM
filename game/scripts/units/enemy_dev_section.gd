class_name EnemyDevSection
extends Node
## Abschnitt „Gegner“ im Entwickler-Panel (Ticket #36). Jede Aktion geht über
## EnemySpawnManager.request_dev als Wunsch an den Host (nur Debug-Build).
##
## - Gegnertyp und Stufe wählen (Regler), dann „Am Mauszeiger erscheinen
##   lassen“: Der nächste Linksklick in die Welt (nicht aufs Panel) setzt den
##   Gegner an diese Stelle, Blick zur eigenen Figur. Esc bzw. Rechtsklick
##   bricht ab. Solche Gegner gehören zu keinem Spawnbereich.
## - Alle Gegner töten (ohne Erfahrung), alle Spawnbereiche zurücksetzen.
## - Spawnbereiche und Respawnzeiten anzeigen (Kreise am Boden, Beschriftung;
##   die Zeiten kennt nur der Host).
## - Schneller Respawn (respawn_schnell_s statt respawn_s), zum Testen.

## Ebene „Welt“ für den Strahl vom Mauszeiger.
const GROUND_MASK := 1
const RAY_LENGTH := 500.0

var _world: GameWorld = null
var _info: Label = null
var _type_label: Label = null
var _level_label: Label = null
var _ids: Array[StringName] = []
var _type_index := 0
var _level := 1
var _placing := false


func setup(panel: DevPanel, world: GameWorld) -> void:
	_world = world
	for row in Data.alle_gegner():
		_ids.append(StringName(row.id()))
	var section := panel.add_section("Gegner")
	_info = panel.add_info(section, "")
	_type_label = panel.add_info(section)
	panel.add_slider(section, 0.0, maxf(0.0, _ids.size() - 1), 1.0, 0.0, func(value: float) -> void:
		_type_index = int(value)
		_update_labels())
	_level_label = panel.add_info(section)
	panel.add_slider(section, 1.0, Data.hoechste_stufe(), 1.0, 1.0, func(value: float) -> void:
		_level = int(value)
		_update_labels())
	panel.add_button(section, "Am Mauszeiger erscheinen lassen (dann in die Welt klicken)", func() -> void:
		_placing = true
		_update_info())
	panel.add_button(section, "Alle Gegner töten", _request.bind("kill_all", null))
	panel.add_button(section, "Alle Spawnbereiche zurücksetzen", _request.bind("reset", null))
	panel.add_toggle(section, "Spawnbereiche und Respawnzeiten anzeigen", false, func(on: bool) -> void:
		var manager := _manager()
		if manager != null:
			manager.set_debug_visible(on))
	panel.add_toggle(section, "Schneller Respawn (%s s)" % StatFormat.number(
			Data.konstante(&"respawn_schnell_s", 10.0), 0), false,
			func(on: bool) -> void: _request("fast", on))
	_update_labels()
	var timer := Timer.new()
	timer.wait_time = 0.5
	timer.autostart = true
	timer.timeout.connect(_update_info)
	add_child(timer)


## Wunsch an den Host: Gegner des gewählten Typs und der gewählten Stufe an at.
func request_spawn_at(at: Transform3D) -> void:
	if _ids.is_empty():
		return
	_request("spawn", [String(_ids[_type_index]), _level, at])


func _input(event: InputEvent) -> void:
	if not _placing:
		return
	if event.is_action_pressed(&"ui_cancel") or (event is InputEventMouseButton and event.pressed
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT):
		_placing = false
		_update_info()
		get_viewport().set_input_as_handled()
		return
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	# Klicks auf das Panel (oder andere Oberfläche) zählen nicht.
	if get_viewport().gui_get_hovered_control() != null:
		return
	var point: Variant = _ground_under_mouse(click.position)
	if point == null:
		return
	_placing = false
	get_viewport().set_input_as_handled()
	request_spawn_at(_facing_player(point))
	_update_info()


func _ground_under_mouse(screen: Vector2) -> Variant:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null
	var from := camera.project_ray_origin(screen)
	var to := from + camera.project_ray_normal(screen) * RAY_LENGTH
	var query := PhysicsRayQueryParameters3D.create(from, to, GROUND_MASK)
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		return hit["position"]
	var player := _world.get_local_player()
	var plane := Plane(Vector3.UP, player.global_position.y if player != null else 0.0)
	return plane.intersects_ray(from, camera.project_ray_normal(screen))


## Lage an point, Blick zur eigenen Figur.
func _facing_player(point: Vector3) -> Transform3D:
	var player := _world.get_local_player()
	var basis := Basis.IDENTITY
	if player != null:
		var to := player.global_position - point
		to.y = 0.0
		if to.length_squared() > 0.0001:
			basis = Basis(Vector3.UP, atan2(-to.x, -to.z))
	return Transform3D(basis, point)


func _request(action: String, value: Variant) -> void:
	var manager := _manager()
	if manager != null:
		manager.request_dev(action, value)


func _manager() -> EnemySpawnManager:
	return EnemySpawnManager.get_instance(get_tree())


func _update_labels() -> void:
	if _ids.is_empty():
		_type_label.text = "Gegnertyp: – (gegner.csv leer)"
	else:
		var row := Data.gegner(_ids[_type_index])
		_type_label.text = "Gegnertyp: %s (%s, %s)" % [row.get_value("name", ""), _ids[_type_index],
				row.get_value("rang", "")]
	_level_label.text = "Stufe: %d" % _level


func _update_info() -> void:
	if _info == null or not _info.is_visible_in_tree():
		return
	var manager := _manager()
	var lines: PackedStringArray = []
	if _placing:
		lines.append("Linksklick in die Welt setzt den Gegner (Esc bricht ab).")
	if manager != null:
		var alive := 0
		var dead := 0
		for enemy in manager.get_enemies():
			if enemy.is_dead():
				dead += 1
			else:
				alive += 1
		lines.append("Gegner: %d lebend, %d Leichen" % [alive, dead])
		if Network.is_host():
			lines.append("Spawnbereiche: %s" % ("aktiv" if manager.is_started() else "warten auf das NavMesh"))
	_info.text = "\n".join(lines)
