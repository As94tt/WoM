class_name PlayerCharacter
extends CharacterBody3D
## Spielfigur mit WoW-Bewegung (Ticket #16). Graubox: Kapsel mit „Nase“,
## Vorderseite ist -Z. Der Ursprung liegt an den Füßen.
##
## Die Figur bewegt sich nur auf der Instanz, die ihre Multiplayer-Authority
## hat (der Spieler, dem sie gehört). Die Eingabe kommt vom Kindknoten
## PlayerInput, der nur dort aktiv ist. Position und Drehung liegen in den
## normalen Eigenschaften position und rotation (Drehung nur um die Hochachse),
## damit ein MultiplayerSynchronizer sie in M1 (#30) übertragen kann.
##
## Ohne Netzwerk (OfflineMultiplayerPeer) ist die eigene Peer-ID 1 und die
## Figur gehört standardmäßig Peer 1, also dem lokalen Spieler.

## Wird gesendet, wenn die Figur anfängt oder aufhört, sich zu bewegen
## (für den Zauberabbruch bei Bewegung, #33).
signal moving_changed(moving: bool)

## Bewegungswerte aus res://data/movement/.
@export var movement: MovementData = preload("res://data/movement/player_movement.tres")

## Peer, dem die Figur gehört. Setzt die Multiplayer-Authority.
@export var peer_id: int = 1:
	set(value):
		peer_id = value
		set_multiplayer_authority(value)

## Faktor auf alle Geschwindigkeiten. Auren wie Verlangsamung oder Sprint
## (#32) verändern diesen Wert, Betäubung setzt ihn z. B. auf 0.
var speed_multiplier: float = 1.0

## Bewegungsabsicht, gesetzt von PlayerInput: x = seitwärts (+1 rechts),
## y = vorwärts (+1 vor, -1 zurück). Werte von -1 bis 1.
var move_input := Vector2.ZERO
## Drehabsicht, gesetzt von PlayerInput: +1 = nach links, -1 = nach rechts.
var turn_input := 0.0
## Gehen statt Laufen (Numpad /).
var walking := false

## true, solange sich die Figur bewegt (auch in der Luft). Drehen auf der
## Stelle zählt nicht als Bewegung.
var is_moving := false:
	set(value):
		if value == is_moving:
			return
		is_moving = value
		moving_changed.emit(value)

var _jump_requested := false
## Waagerechter Schwung, der in der Luft erhalten bleibt.
var _air_velocity := Vector3.ZERO

## Kleinste Geschwindigkeit, ab der die Figur als „in Bewegung“ gilt.
const MOVING_THRESHOLD := 0.05
## Wie weit beim Stufensteigen nach vorn geprüft wird (Kapselradius), in Metern.
const STEP_PROBE_DISTANCE := 0.4


func _ready() -> void:
	set_multiplayer_authority(peer_id)
	floor_max_angle = deg_to_rad(movement.max_slope_deg)
	floor_snap_length = movement.step_height
	floor_constant_speed = true
	floor_stop_on_slope = true


## Laufgeschwindigkeit dieser Figur (Daten mal Aurenfaktor), in m/s.
func get_run_speed() -> float:
	return movement.run_speed * speed_multiplier


## Rückwärtsgeschwindigkeit dieser Figur, in m/s.
func get_backward_speed() -> float:
	return movement.backward_speed * speed_multiplier


## Gehgeschwindigkeit dieser Figur, in m/s.
func get_walk_speed() -> float:
	return movement.walk_speed * speed_multiplier


## Springt beim nächsten Physikschritt, falls die Figur auf dem Boden steht.
func request_jump() -> void:
	_jump_requested = true


## Dreht die Figur um die Hochachse (Bogenmaß, positiv = nach links).
func add_yaw(radians: float) -> void:
	rotation.y = wrapf(rotation.y + radians, -PI, PI)


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	if turn_input != 0.0:
		add_yaw(turn_input * deg_to_rad(movement.turn_speed_deg) * delta)

	var jumping := false
	if is_on_floor():
		# Am Boden folgt die Bewegung direkt der Eingabe.
		_air_velocity = _ground_velocity()
		velocity.x = _air_velocity.x
		velocity.z = _air_velocity.z
		velocity.y = 0.0
		if _jump_requested:
			velocity.y = sqrt(2.0 * movement.gravity * movement.jump_height)
			jumping = true
	else:
		# In der Luft bleibt der Schwung vom Absprung (bzw. von der Kante)
		# erhalten: nur Schwerkraft, keine Lenkung. Drehen geht weiterhin (oben).
		# Der Schwung wird jedes Bild neu angesetzt, damit man nach einem
		# Sprung gegen eine Kiste oben auf ihr weiterläuft.
		velocity.x = _air_velocity.x
		velocity.z = _air_velocity.z
		velocity.y -= movement.gravity * delta
	_jump_requested = false

	var stepped := false
	if is_on_floor() and not jumping:
		stepped = _try_step_up(Vector3(velocity.x, 0.0, velocity.z) * delta)
	if not stepped:
		move_and_slide()

	var real := get_real_velocity() if not stepped else velocity
	is_moving = not is_on_floor() or Vector2(real.x, real.z).length() > MOVING_THRESHOLD


## Bodengeschwindigkeit aus der Eingabe. Diagonal ist nicht schneller als
## geradeaus; rückwärts (auch schräg) gilt die Rückwärtsgeschwindigkeit,
## seitwärts die Laufgeschwindigkeit; Gehen begrenzt alle Richtungen.
func _ground_velocity() -> Vector3:
	if move_input == Vector2.ZERO:
		return Vector3.ZERO
	var dir := move_input.normalized()
	var speed := get_backward_speed() if dir.y < 0.0 else get_run_speed()
	if walking:
		speed = minf(speed, get_walk_speed())
	var local := Vector3(dir.x, 0.0, -dir.y) * speed
	return global_basis * local


## Steigt automatisch über eine Stufe bis movement.step_height, wenn die
## Bewegung an einer Kante hängen bleibt. Gibt true zurück, wenn die Figur
## dabei schon bewegt wurde.
func _try_step_up(motion: Vector3) -> bool:
	if motion == Vector3.ZERO:
		return false
	var hit := KinematicCollision3D.new()
	# Nur wenn eine Wand (kein begehbarer Boden) im Weg ist.
	if not test_move(global_transform, motion, hit) or _is_walkable(hit.get_normal()):
		return false
	var up := Vector3.UP * movement.step_height
	var t := global_transform
	if test_move(t, up):
		return false # Kein Platz nach oben.
	t.origin += up
	# Auf Stufenhöhe mindestens eine Kapselbreite (Radius) nach vorn prüfen,
	# damit unten die Oberseite der Stufe getroffen wird und nicht nur die
	# runde Kapsel an der Kante hängt (das würde zu hohe Kanten erlauben).
	var probe := motion.normalized() * maxf(motion.length(), STEP_PROBE_DISTANCE)
	# recovery_as_collision: Steckt die angehobene Kapsel schon in der Kante
	# (Kante höher als step_height), zählt das als blockiert.
	if test_move(t, probe, null, safe_margin, true):
		return false # Auch auf Stufenhöhe blockiert: Wand oder zu hohe Kante.
	t.origin += probe
	if not test_move(t, -up, hit, safe_margin, true) or not _is_walkable(hit.get_normal()):
		return false # Kein begehbarer Boden auf der Stufe (z. B. steiler Hang).
	var rise := movement.step_height - hit.get_travel().length()
	if rise < 0.01:
		return false # Keine Stufe, nur eine flache Kante.
	# Die Kapsel liegt danach komplett über der Stufenoberkante; deshalb reicht
	# die normale Bewegung dieses Bildes plus die Stufenhöhe.
	global_position += motion + Vector3.UP * rise
	return true


func _is_walkable(normal: Vector3) -> bool:
	return normal.angle_to(Vector3.UP) <= floor_max_angle + 0.01
