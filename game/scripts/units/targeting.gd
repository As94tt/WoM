class_name Targeting
extends Node
## Zielauswahl des eigenen Spielers (Ticket #31). Kindknoten „Targeting“ der
## Spielfigur; existiert wie PlayerInput nur beim Besitzer der Figur.
##
## Eingaben (Input Map, project.godot):
## - Linksklick auf eine Einheit wählt sie (PlayerInput erkennt den Klick und
##   ruft handle_world_click); Rechtsklick auf eine angreifbare Einheit wählt
##   sie und schaltet den automatischen Angriff ein (der Angriff selbst folgt
##   in #34). Ein Klick ins Leere ändert das Ziel nicht.
## - Tab (target_next): nächster Feind vor dem Spieler bis
##   zielwahl_reichweite, nach Entfernung sortiert; erneutes Drücken wechselt
##   zum nächstweiteren, nach dem letzten wieder zum nächsten.
##   Shift + Tab (target_previous): dieselbe Liste rückwärts.
## - F1 (target_self): sich selbst. F2–F5 (target_party_1..4): Gruppen-
##   mitglieder, ohne Wirkung, bis es Gruppen gibt.
## - Esc hebt das Ziel auf, wenn kein Fenster offen ist (Hud.handle_cancel).
##
## Netzwerk: Das Ziel wird lokal gewählt und angezeigt. Jede Änderung meldet
## die Figur dem Host (PlayerCharacter.report_target), damit er das Ziel jedes
## Spielers kennt (für Fähigkeiten, #33). Leben und Ressourcen des Ziels
## kommen wie bei allen Einheiten vom Host (StatsSync).
##
## Am Boden unter dem Ziel liegt ein Kreis in der Farbe der Gesinnung
## (UnitColors, Theme).

## Das Ziel hat gewechselt (null = kein Ziel).
signal target_changed(target: Unit)
## Automatischer Angriff an oder aus.
signal auto_attack_changed(active: bool)

const NEXT_ACTION := &"target_next"
const PREVIOUS_ACTION := &"target_previous"
const SELF_ACTION := &"target_self"
const PARTY_ACTIONS: Array[StringName] = [&"target_party_1", &"target_party_2",
		&"target_party_3", &"target_party_4"]
## Klick-Strahl: Ebenen „Welt“ (verdeckt) und „Spielfiguren“ (Einheiten).
const CLICK_MASK := 1 | 2
const CLICK_RAY_LENGTH := 300.0
## Bodenkreis: Ring etwas größer als der Körper.
const RING_MARGIN := 0.25
const RING_THICKNESS := 0.08
const RING_LIFT := 0.05

var target: Unit = null
var auto_attack := false

var _ring: MeshInstance3D = null
var _ring_material: StandardMaterial3D = null

@onready var _player: PlayerCharacter = get_parent() as PlayerCharacter


func _ready() -> void:
	_create_ring()


func _exit_tree() -> void:
	if _ring != null:
		_ring.queue_free()
		_ring = null


func _process(_delta: float) -> void:
	# Getarnte Feinde (#32) verliert man als Ziel.
	if target != null and is_instance_valid(target) and not target.is_visible_to(_player):
		select(null)
	_update_ring()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.is_echo():
		return
	if PlayerInput.is_keyboard_blocked(self):
		return
	# Shift + Tab zuerst prüfen: Tab allein passt auch auf Shift + Tab.
	if event.is_action_pressed(PREVIOUS_ACTION, false, true):
		cycle(true)
	elif event.is_action_pressed(NEXT_ACTION, false, true):
		cycle(false)
	elif event.is_action_pressed(SELF_ACTION):
		select(_player)
	else:
		var handled := false
		for index in PARTY_ACTIONS.size():
			if event.is_action_pressed(PARTY_ACTIONS[index]):
				select_party_member(index + 1)
				handled = true
				break
		if not handled:
			return
	get_viewport().set_input_as_handled()


# --- Auswahl -----------------------------------------------------------------

func has_target() -> bool:
	return target != null


## Wählt unit als Ziel. attack = automatischen Angriff einschalten (nur bei
## angreifbaren Einheiten). Ein laufender automatischer Angriff bleibt beim
## Wechsel auf eine andere angreifbare Einheit an.
func select(unit: Unit, attack := false) -> void:
	if unit != null and (not is_instance_valid(unit) or not unit.is_inside_tree()):
		unit = null
	var attackable := unit != null and unit.can_be_attacked_by(_player)
	var new_attack := attackable and (attack or auto_attack)
	if unit == target and new_attack == auto_attack:
		return
	if unit != target:
		if target != null and target.tree_exiting.is_connected(_on_target_exiting):
			target.tree_exiting.disconnect(_on_target_exiting)
		target = unit
		if target != null:
			target.tree_exiting.connect(_on_target_exiting, CONNECT_ONE_SHOT)
		target_changed.emit(target)
	if new_attack != auto_attack:
		auto_attack = new_attack
		auto_attack_changed.emit(auto_attack)
	_player.report_target(target, auto_attack)


## Ziel aufheben (Esc). Gibt true zurück, wenn es ein Ziel gab.
func clear() -> bool:
	if target == null:
		return false
	select(null)
	return true


## Gruppenmitglied Nummer index (1–4) wählen. Ohne Gruppen ohne Wirkung.
func select_party_member(_index: int) -> void:
	pass


## Tab bzw. Shift + Tab: nächster bzw. vorheriger Feind in der Liste.
func cycle(backward: bool) -> void:
	var candidates := get_tab_candidates()
	if candidates.is_empty():
		return
	var index := candidates.find(target)
	if index == -1:
		select(candidates[0])
		return
	var step := -1 if backward else 1
	select(candidates[wrapi(index + step, 0, candidates.size())])


## Einheiten, die Tab wählen kann, nach Entfernung sortiert: angreifbar
## (feindlich oder neutral), lebend, sichtbar, bis zielwahl_reichweite, vor
## dem Spieler und in Sichtlinie.
func get_tab_candidates() -> Array[Unit]:
	var result: Array[Unit] = []
	var max_range := Data.konstante(&"zielwahl_reichweite", 40.0)
	var distances := {}
	for unit in Unit.all_units(get_tree()):
		if unit == _player or not unit.is_tab_targetable() or not unit.is_visible_to(_player) \
				or not unit.can_be_attacked_by(_player):
			continue
		var distance := _player.distance_to_unit(unit)
		if distance > max_range or not _player.is_in_front(unit) or not _player.has_line_of_sight_to(unit):
			continue
		distances[unit] = distance
		result.append(unit)
	result.sort_custom(func(a: Unit, b: Unit) -> bool:
		if is_equal_approx(distances[a], distances[b]):
			return a.get_instance_id() < b.get_instance_id()
		return distances[a] < distances[b])
	return result


## Klick in die Spielwelt an screen_position (von PlayerInput). Linksklick
## wählt die getroffene Einheit, Rechtsklick wählt sie und greift an.
func handle_world_click(screen_position: Vector2, right_button: bool) -> void:
	var unit := unit_at_screen_position(screen_position)
	if unit == null or not unit.is_visible_to(_player):
		return
	select(unit, right_button)


## Einheit unter dem Mauszeiger oder null (Wände verdecken).
func unit_at_screen_position(screen_position: Vector2) -> Unit:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null
	var from := camera.project_ray_origin(screen_position)
	var to := from + camera.project_ray_normal(screen_position) * CLICK_RAY_LENGTH
	var query := PhysicsRayQueryParameters3D.create(from, to, CLICK_MASK)
	var hit := _player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	var node := hit["collider"] as Node
	while node != null and not node is Unit:
		node = node.get_parent()
	return node as Unit


# --- Bodenkreis --------------------------------------------------------------

func _create_ring() -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = 1.0 - RING_THICKNESS
	mesh.outer_radius = 1.0
	mesh.rings = 48
	mesh.ring_segments = 6
	_ring_material = StandardMaterial3D.new()
	_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = _ring_material
	_ring = MeshInstance3D.new()
	_ring.name = "TargetRing"
	_ring.mesh = mesh
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.top_level = true
	_ring.visible = false
	add_child(_ring)


func _update_ring() -> void:
	if _ring == null:
		return
	var show := target != null and is_instance_valid(target) and target.is_inside_tree() \
			and target.is_visible_to(_player)
	_ring.visible = show
	if not show:
		return
	var radius := target.get_body_radius() + RING_MARGIN
	_ring.global_transform = Transform3D(Basis.from_scale(Vector3(radius, 0.3, radius)),
			target.global_position + Vector3.UP * RING_LIFT)
	_ring_material.albedo_color = UnitColors.reaction_color(target.get_reaction_to(_player))


func _on_target_exiting() -> void:
	# Ziel verschwindet (z. B. Spieler hat die Welt verlassen).
	target = null
	target_changed.emit(null)
	if auto_attack:
		auto_attack = false
		auto_attack_changed.emit(false)
	if is_inside_tree() and _player != null and _player.is_inside_tree():
		_player.report_target(null, false)
