class_name PlayerCamera
extends Node3D
## Verfolgerkamera der Spielfigur (Ticket #16). Kind von PlayerCharacter,
## aber top_level, damit sie unabhängig von der Figur gedreht werden kann.
## Der Knoten sitzt am Blickpunkt (Kopfhöhe), der SpringArm3D darunter hält
## die Kamera auf Abstand und zieht sie näher heran, wenn eine Wand (Ebene
## „Welt“) zwischen Figur und Kamera steht.
##
## Die Drehung setzt sich aus der Blickrichtung der Figur und einem Versatz
## (yaw_offset, linke Maustaste) zusammen. Dreht sich die Figur mit A/D, dreht
## die Kamera also mit. Nur die Kamera des lokalen Spielers ist aktiv.

## Kameraeinstellungen aus res://data/camera/.
@export var settings: CameraSettings = preload("res://data/camera/player_camera.tres")

## Seitlicher Versatz zur Blickrichtung der Figur (Bogenmaß).
var yaw_offset := 0.0
## Kamerawinkel nach oben/unten (Bogenmaß, negativ = von oben).
var pitch := 0.0
## Solange true, schwenkt die Kamera hinter die Figur zurück (yaw_offset → 0).
## Wird von PlayerInput gesetzt.
var follow_behind := false

@onready var _player: PlayerCharacter = get_parent()
@onready var _arm: SpringArm3D = $SpringArm
@onready var _camera: Camera3D = $SpringArm/Camera

var _target_distance := 0.0


func _ready() -> void:
	top_level = true
	pitch = deg_to_rad(settings.start_pitch_deg)
	_target_distance = settings.start_distance
	_arm.spring_length = _target_distance
	_update_transform()


func _process(delta: float) -> void:
	var is_local := _player.is_multiplayer_authority()
	if _camera.current != is_local:
		_camera.current = is_local
	if follow_behind and yaw_offset != 0.0:
		yaw_offset = lerp_angle(yaw_offset, 0.0, 1.0 - exp(-settings.return_speed * delta))
		if absf(yaw_offset) < 0.001:
			yaw_offset = 0.0
	_arm.spring_length = lerpf(_arm.spring_length, _target_distance,
			1.0 - exp(-settings.zoom_smoothing * delta))
	_update_transform()


## Dreht nur die Kamera um die Figur (Bogenmaß, positiv = nach links).
func add_yaw_offset(radians: float) -> void:
	yaw_offset = wrapf(yaw_offset + radians, -PI, PI)


## Kamerawinkel nach oben/unten ändern, begrenzt auf die Werte aus den Daten.
func add_pitch(radians: float) -> void:
	pitch = clampf(pitch + radians, deg_to_rad(settings.min_pitch_deg),
			deg_to_rad(settings.max_pitch_deg))


## Zoomen: steps > 0 entfernt die Kamera, steps < 0 holt sie heran.
func zoom(steps: float) -> void:
	_target_distance = clampf(_target_distance + steps * settings.zoom_step,
			settings.min_distance, settings.max_distance)


## Aktueller Zielabstand der Kamera (ohne Verkürzung durch Wände), in Metern.
func get_target_distance() -> float:
	return _target_distance


func _update_transform() -> void:
	global_position = _player.global_position + Vector3.UP * settings.target_height
	global_basis = Basis.from_euler(Vector3(pitch, _player.global_rotation.y + yaw_offset, 0.0))
