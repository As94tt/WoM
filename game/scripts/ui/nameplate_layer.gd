class_name NameplateLayer
extends Control
## Namensplaketten aller Einheiten (Ticket #31, ersetzt die Plakette aus #30).
## Liegt im HUD unter allen Fenstern und setzt je Bild jede Plakette
## (UnitNameplate) über den Kopf ihrer Einheit (Unit.get_nameplate_position,
## projiziert mit der aktuellen Kamera).
##
## - Plaketten erscheinen bis plaketten_reichweite (spielkonstanten.csv) von
##   der eigenen Figur; die eigene Figur hat keine (Name steht im
##   Spielerrahmen).
## - V (toggle_nameplates_enemy) blendet die Plaketten feindlicher und
##   neutraler Einheiten ein und aus, Shift + V (toggle_nameplates_friendly)
##   die freundlicher Einheiten und Mitspieler. Der Zustand wird in
##   GameSettings gespeichert. Die Anzeige über Übungspuppen bleibt sichtbar.
## - Das Ziel wird zuletzt gezeichnet (liegt oben).
##
## Rein lokal; Leben und Stufe kommen vom Host (StatsSync).

const PLATE_SCENE := preload("res://scenes/ui/hud/unit_nameplate.tscn")
const ENEMY_ACTION := &"toggle_nameplates_enemy"
const FRIENDLY_ACTION := &"toggle_nameplates_friendly"

var show_enemies := true
var show_friends := true

var _player: PlayerCharacter = null
var _targeting: Targeting = null
## Plaketten nach Instanz-ID der Einheit.
var _plates: Dictionary[int, UnitNameplate] = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_enemies = GameSettings.is_enemy_nameplates_shown()
	show_friends = GameSettings.is_friendly_nameplates_shown()


## Verbindet die Plaketten mit der eigenen Figur (Entfernung, Gesinnung, Ziel).
func setup(player: PlayerCharacter) -> void:
	_player = player
	_targeting = player.get_targeting()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.is_echo() or _player == null:
		return
	if PlayerInput.is_keyboard_blocked(self):
		return
	# Shift + V zuerst: V allein passt auch auf Shift + V.
	if event.is_action_pressed(FRIENDLY_ACTION, false, true):
		show_friends = not show_friends
		GameSettings.set_friendly_nameplates_shown(show_friends)
	elif event.is_action_pressed(ENEMY_ACTION, false, true):
		show_enemies = not show_enemies
		GameSettings.set_enemy_nameplates_shown(show_enemies)
	else:
		return
	get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if _player == null or not is_instance_valid(_player) or camera == null:
		for plate: UnitNameplate in _plates.values():
			plate.visible = false
		return
	var max_range := Data.konstante(&"plaketten_reichweite", 40.0)
	var target: Unit = _targeting.target if _targeting != null and is_instance_valid(_targeting) else null
	var seen: Dictionary[int, bool] = {}
	var target_plate: UnitNameplate = null
	for unit in Unit.all_units(get_tree()):
		if unit == _player:
			continue
		seen[unit.get_instance_id()] = true
		var plate := _plate_for(unit)
		var anchor := unit.get_nameplate_position()
		var hostile := unit.get_reaction_to(_player) != Unit.Reaction.FRIENDLY
		var show_plate := show_enemies if hostile else show_friends
		var shown := unit.is_visible_to(_player) and not camera.is_position_behind(anchor) \
				and _player.distance_to_unit(unit) <= max_range \
				and (show_plate or unit.get_overhead_text() != "")
		plate.visible = shown
		if not shown:
			continue
		plate.update_from(unit, _player, unit == target, show_plate)
		plate.place_at(camera.unproject_position(anchor))
		if unit == target:
			target_plate = plate
	for id: int in _plates.keys():
		if not seen.has(id):
			_plates[id].queue_free()
			_plates.erase(id)
	if target_plate != null and target_plate.get_index() != get_child_count() - 1:
		move_child(target_plate, -1)


func _plate_for(unit: Unit) -> UnitNameplate:
	var plate: UnitNameplate = _plates.get(unit.get_instance_id())
	if plate == null:
		plate = PLATE_SCENE.instantiate()
		add_child(plate)
		plate.clicked.connect(_on_plate_clicked)
		_plates[unit.get_instance_id()] = plate
	return plate


func _on_plate_clicked(unit: Unit, right_button: bool) -> void:
	if _targeting != null and is_instance_valid(_targeting):
		_targeting.select(unit, right_button)
