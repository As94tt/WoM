class_name MovementCheck
extends RefCounted
## Grobe Plausibilitätsprüfung der Bewegung einer fremden Figur auf dem Host
## (Ticket #30). Jede empfangene Meldung (Position, Zeitstempel des Besitzers,
## Teleport-Zähler) wird mit der letzten gültigen verglichen. Grenzwerte aus
## MovementCheckData; erlaubt sind Laufen (mal Faktor), Springen, Hänge und
## Fallen. Für Koop unter Freunden reicht das; es ist kein Anti-Cheat.
##
## Teleports (Entwickler-Panel, Wiedereinstieg, Rücksetzen) befiehlt nur der
## Host: expect_teleport() vor dem Befehl, danach gilt die erste Meldung mit
## neuem Teleport-Zähler am Ziel als neuer Ausgangspunkt. Ein Teleport, den
## der Host nicht befohlen hat, ist ein Verstoß.

enum Result { OK, IGNORED, VIOLATION }

var _data: MovementCheckData
var _has_baseline := false
var _last_position := Vector3.ZERO
var _last_yaw := 0.0
var _last_time := 0
var _last_seq := 0
var _awaiting_teleport := false
var _teleport_target := Vector3.ZERO


func _init(data: MovementCheckData) -> void:
	_data = data


## Letzte gültige Position (Ziel beim Zurücksetzen).
func get_last_valid_transform() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, _last_yaw), _last_position)


## Der Host befiehlt gleich einen Teleport nach target. Bis die Figur dort
## ankommt, werden Meldungen von der alten Stelle ignoriert.
func expect_teleport(target: Vector3) -> void:
	_awaiting_teleport = true
	_teleport_target = target


## Prüft eine Meldung. movement und run_speed beschreiben die Figur (höchste
## Laufgeschwindigkeit in m/s, inklusive Auren).
func check(position: Vector3, yaw: float, time_ms: int, seq: int,
		movement: MovementData, run_speed: float) -> Result:
	if not _has_baseline:
		_accept(position, yaw, time_ms, seq)
		return Result.OK
	if seq != _last_seq:
		# Die Figur wurde teleportiert. Gültig nur, wenn der Host es befohlen
		# hat und sie am Ziel ankommt.
		if _awaiting_teleport and position.distance_to(_teleport_target) <= _data.teleport_arrival_m:
			_awaiting_teleport = false
			_accept(position, yaw, time_ms, seq)
			return Result.OK
		if _awaiting_teleport:
			return Result.IGNORED
		return Result.VIOLATION
	if _awaiting_teleport or time_ms <= _last_time:
		return Result.IGNORED  # Alte Meldung oder Befehl noch unterwegs.

	var dt := clampf((time_ms - _last_time) / 1000.0, 0.001, 2.0)
	var delta := position - _last_position
	var horizontal := Vector2(delta.x, delta.z).length()
	var drop := maxf(0.0, -delta.y)
	# Waagerecht: Laufen mal Faktor; beim Rutschen und Fallen an steilen Hängen
	# kommt höchstens so viel dazu, wie die Figur dabei fällt.
	var allowed_horizontal := run_speed * _data.speed_factor * dt + drop + _data.tolerance_m
	# Nach oben: Absprung oder Hang hinauf (je nachdem, was schneller ist),
	# plus eine Stufe.
	var jump_speed := sqrt(2.0 * movement.gravity * movement.jump_height)
	var slope_speed := run_speed * tan(deg_to_rad(movement.max_slope_deg))
	var allowed_up := maxf(jump_speed, slope_speed) * _data.speed_factor * dt \
			+ movement.step_height + _data.tolerance_m
	if horizontal > _data.teleport_threshold_m or horizontal > allowed_horizontal \
			or delta.y > allowed_up:
		return Result.VIOLATION
	_accept(position, yaw, time_ms, seq)
	return Result.OK


func _accept(position: Vector3, yaw: float, time_ms: int, seq: int) -> void:
	_has_baseline = true
	_last_position = position
	_last_yaw = yaw
	_last_time = time_ms
	_last_seq = seq
