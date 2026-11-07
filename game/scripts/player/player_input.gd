class_name PlayerInput
extends Node
## Eingabe für die eigene Spielfigur (Ticket #16): Tastatur und Maus nach
## klassischer WoW-Steuerung. Alle Tasten sind benannte Aktionen der Input Map
## (project.godot), damit sie später im Optionsmenü neu belegt werden können.
##
## Nur aktiv auf der Instanz, die die Multiplayer-Authority der Figur hat;
## fremde Figuren reagieren nicht auf die lokale Eingabe.
##
## Trennung von Oberfläche und Spielwelt (für das HUD, #17):
## - Mausklicks und Mausrad werden in _unhandled_input ausgewertet. Ein
##   Control mit mouse_filter STOP (z. B. ein Button der Aktionsleiste)
##   bekommt den Klick zuerst; Kamera und Bewegung sehen ihn dann nicht.
## - Erst wenn ein Ziehen in der Spielwelt begonnen hat, werden Mausbewegung
##   und Loslassen in _input ausgewertet, damit das Ziehen nicht abbricht,
##   wenn der (ausgeblendete) Zeiger über einem UI-Element liegt.
## - Ein Klick in die Spielwelt nimmt der Oberfläche den Fokus.
## - Hat ein Textfeld (LineEdit/TextEdit) den Fokus, z. B. später der Chat,
##   werden die Bewegungstasten ignoriert.

## Kamera der Figur.
@export var camera: PlayerCamera

## Automatisch laufen (Num Lock). Endet bei W oder S.
var autorun := false
## Gehen statt Laufen (Numpad /). Beim Start gilt Laufen.
var walking := false

@onready var _player: PlayerCharacter = get_parent()

## Linke Maustaste in der Spielwelt gedrückt: nur Kamera drehen.
var _look_held := false
## Rechte Maustaste in der Spielwelt gedrückt: Figur und Kamera drehen.
var _steer_held := false
## Position des Mauszeigers beim Ausblenden (Viewport-Koordinaten).
var _cursor_position := Vector2.ZERO


func _ready() -> void:
	# Eingabe vor der Bewegung der Figur auswerten (kein Frame Verzögerung).
	process_physics_priority = -1


func _exit_tree() -> void:
	_release_mouse_buttons()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_release_mouse_buttons()


func _is_local() -> bool:
	return _player != null and _player.is_multiplayer_authority()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_local():
		return
	if event is InputEventMouseButton and event.pressed:
		_handle_mouse_press(event)
		return
	if event.is_action_pressed("jump"):
		_player.request_jump()
	elif event.is_action_pressed("autorun_toggle"):
		autorun = not autorun
	elif event.is_action_pressed("walk_toggle"):
		walking = not walking
	elif event.is_action_pressed("move_forward") or event.is_action_pressed("move_backward"):
		autorun = false
	else:
		return
	get_viewport().set_input_as_handled()


func _handle_mouse_press(event: InputEventMouseButton) -> void:
	if event.is_action_pressed("camera_zoom_in"):
		camera.zoom(-1.0)
	elif event.is_action_pressed("camera_zoom_out"):
		camera.zoom(1.0)
	elif event.is_action_pressed("camera_look"):
		_look_held = true
		_update_cursor()
	elif event.is_action_pressed("camera_steer"):
		_steer_held = true
		_update_cursor()
	else:
		return
	# Klick in die Spielwelt: Fokus von UI-Elementen nehmen, damit z. B. die
	# Leertaste keinen zuletzt geklickten Button auslöst.
	get_viewport().gui_release_focus()
	get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not (_look_held or _steer_held):
		return
	if event is InputEventMouseMotion:
		var sensitivity := deg_to_rad(camera.settings.mouse_sensitivity_deg)
		var rel: Vector2 = event.screen_relative * sensitivity
		if _steer_held:
			_player.add_yaw(-rel.x)
		else:
			camera.add_yaw_offset(-rel.x)
		camera.add_pitch(-rel.y)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and not event.pressed:
		if _look_held and event.is_action_released("camera_look"):
			_look_held = false
		elif _steer_held and event.is_action_released("camera_steer"):
			_steer_held = false
		else:
			return
		_update_cursor()
		get_viewport().set_input_as_handled()


func _physics_process(_delta: float) -> void:
	if not _is_local():
		return
	var forward := 0.0
	var strafe := 0.0
	var turn := 0.0
	var keys_held := false
	if not _text_field_has_focus():
		var w := Input.is_action_pressed("move_forward")
		var s := Input.is_action_pressed("move_backward")
		var q := Input.is_action_pressed("strafe_left")
		var e := Input.is_action_pressed("strafe_right")
		var a := Input.is_action_pressed("turn_left")
		var d := Input.is_action_pressed("turn_right")
		forward += float(w) - float(s)
		strafe += float(e) - float(q)
		if _steer_held:
			# Mit rechter Maustaste werden A/D zu Seitwärts gehen.
			strafe += float(d) - float(a)
		else:
			turn += float(a) - float(d)
		keys_held = w or s or q or e
	if autorun or (_look_held and _steer_held):
		forward += 1.0
	_player.move_input = Vector2(clampf(strafe, -1.0, 1.0), clampf(forward, -1.0, 1.0))
	_player.turn_input = turn
	_player.walking = walking
	# Kamera schwenkt hinter die Figur zurück bei rechter Maustaste oder
	# W/S/Q/E. Solange nur die linke Maustaste gehalten wird, bleibt sie, wo
	# der Spieler sie hingedreht hat.
	camera.follow_behind = _steer_held or (keys_held and not _look_held)


## Blendet den Zeiger aus, solange eine Maustaste in der Spielwelt gehalten
## wird, und zeigt ihn beim Loslassen an derselben Stelle wieder.
func _update_cursor() -> void:
	var dragging := _look_held or _steer_held
	if dragging and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_cursor_position = get_viewport().get_mouse_position()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif not dragging and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().warp_mouse(_cursor_position)


func _release_mouse_buttons() -> void:
	if not (_look_held or _steer_held):
		return
	_look_held = false
	_steer_held = false
	if is_inside_tree():
		_update_cursor()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _text_field_has_focus() -> bool:
	var focus := get_viewport().gui_get_focus_owner()
	return focus is LineEdit or focus is TextEdit
