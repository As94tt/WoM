class_name PlayerCharacter
extends Unit
## Spielfigur mit WoW-Bewegung (Ticket #16). Graubox: Kapsel mit „Nase“,
## Vorderseite ist -Z. Der Ursprung liegt an den Füßen.
##
## Die Figur bewegt sich nur auf der Instanz, die ihre Multiplayer-Authority
## hat (der Spieler, dem sie gehört). Die Eingabe kommt vom Kindknoten
## PlayerInput, der nur dort existiert; Kamera und Eingabe fremder Figuren
## werden entfernt.
##
## Netzwerk (#30):
## - Der Host erzeugt die Figur (MultiplayerSpawner der Welt). Der Knotenname
##   ist die Peer-ID des Besitzers und bestimmt die Authority. Aussehen (Volk,
##   Geschlecht, Klasse), Name, Stufe und Startposition überträgt „ServerSync“
##   (Authority Host) beim Erzeugen bzw. bei Änderung.
## - Der Besitzer bestimmt seine Bewegung selbst (sofort, ohne Verzögerung)
##   und schreibt jeden Physikschritt einen Schnappschuss in die
##   net_*-Eigenschaften, die „MovementSync“ (Authority Besitzer) etwa 20-mal
##   pro Sekunde an alle sendet. Die künstliche Verzögerung (Entwickler-Panel)
##   hält diese Schnappschüsse zurück.
## - Alle anderen zeigen die Figur leicht in der Vergangenheit
##   (NetworkSettings.interpolation_delay_ms) und interpolieren in _process
##   weich zwischen zwei Schnappschüssen, also passend zur Bildrate.
## - Der Host prüft fremde Figuren grob (MovementCheck) und setzt sie bei
##   Verstößen zurück. Teleports befiehlt nur der Host (server_teleport).
##
## Ohne Netzwerk (OfflineMultiplayerPeer) ist die eigene Peer-ID 1 und die
## Figur gehört standardmäßig Peer 1, also dem lokalen Spieler.
##
## Werte (#19): Kindknoten „Stats“ (CharacterStats) mit Attributen, Kampfwerten,
## Leben und Ressourcen; „StatsSync“ (Authority Host) überträgt sie. Die
## Laufgeschwindigkeit folgt dem Wert „movement_speed“ (Eile, später Auren).
##
## Fähigkeiten (#21): Kindknoten „Abilities“ (PlayerAbilities) mit Zauberbuch-
## Reitern, „erlernt“ und der zentralen Funktion use_ability(). Nicht
## synchronisiert; die Stufe kommt aus „Stats“.
##
## Einheit (#31): Die Figur ist eine Unit (Entfernung, Sichtlinie, Gesinnung).
## Die Zielauswahl liegt im Kindknoten „Targeting“, der wie die Eingabe nur
## beim Besitzer existiert. Der Besitzer meldet sein Ziel und den
## automatischen Angriff per RPC an den Host (report_target), der es in
## current_target/auto_attacking führt. Die Namensplakette zeichnet seit #31
## das HUD (NameplateLayer), nicht mehr die Figur selbst.
##
## Wirken (#33): Kindknoten „Caster“ (UnitCaster) mit Zaubern, Abklingzeiten
## und automatischem Angriff, übertragen über „CastSync“ (Authority Host,
## jedes Bild bei Änderung). „GroundTargeting“ (Bodenziel) gibt es wie
## „Targeting“ nur beim Besitzer. moving_changed bricht Zauber ab.
##
## Auren (#32): Kindknoten „Combat“ (UnitCombat), übertragen über StatsSync.
## Betäubt, festgehalten und umgeworfen sperren beim Besitzer Laufen und
## Springen, betäubt und umgeworfen auch das Drehen; Verlangsamung wirkt über
## den Wert „movement_speed“. Bewegungseffekte setzt der Host über
## server_teleport (host_move_to).

## Wird gesendet, wenn die Figur anfängt oder aufhört, sich zu bewegen
## (für den Zauberabbruch bei Bewegung, #33).
signal moving_changed(moving: bool)

enum MoveState { STANDING, RUNNING, JUMPING, FALLING }

const NETWORK_SETTINGS: NetworkSettings = preload("res://data/network/network_settings.tres")
const MOVEMENT_CHECK: MovementCheckData = preload("res://data/network/movement_check.tres")

## Bewegungswerte aus res://data/movement/.
@export var movement: MovementData = preload("res://data/movement/player_movement.tres")

## Peer, dem die Figur gehört. Kommt aus dem Knotennamen (Peer-ID, siehe
## _enter_tree) und bestimmt die Multiplayer-Authority.
var peer_id: int = 1

@export_group("Aussehen")
## Name im Spiel (mit Zusatz bei gleichen Namen, siehe NetPlayerInfo).
@export var display_name: String = "":
	set(value):
		display_name = value
		_update_appearance()
@export var race_id: StringName = &"":
	set(value):
		race_id = value
		_update_appearance()
@export var gender: int = CharacterData.Gender.MALE
@export var class_id: StringName = &"":
	set(value):
		class_id = value
		_update_appearance()
@export var level: int = 1:
	set(value):
		level = value
		_update_appearance()
@export_group("")

## Schnappschuss für MovementSync, geschrieben vom Besitzer.
var net_position := Vector3.ZERO
var net_yaw := 0.0
var net_state: int = MoveState.STANDING
## Zeitstempel des Schnappschusses (Time.get_ticks_msec() beim Besitzer).
var net_time: int = 0
## Zählt Teleports; ändert er sich, springen die anderen ohne Interpolation.
var net_teleport_seq: int = 0

## Bewegungszustand (läuft, springt, steht, fällt), bei fremden Figuren aus
## dem Netz. Für spätere Animationen.
var move_state: MoveState = MoveState.STANDING

## Faktor auf alle Geschwindigkeiten. Seit #19 aus dem Wert „movement_speed“
## der Werte (Stats) gesetzt, auf jeder Instanz gleich: Eile erhöht ihn.
## Auren wie Verlangsamung oder Sprint (#32) ändern ihn nicht direkt, sondern
## über einen Modifikator auf „movement_speed“ (stärkste Verlangsamung als ein
## Modifikator, siehe UnitCombat). Betäubung sperrt die Bewegung direkt.
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

## Besitzer: Schnappschüsse, die wegen künstlicher Verzögerung noch warten.
var _outgoing: Array[Dictionary] = []
## Andere: empfangene Schnappschüsse, nach Zeit sortiert.
var _snapshots: Array[Dictionary] = []
## Andere: geschätzter Abstand zwischen eigener Uhr und Uhr des Besitzers
## (inklusive Laufzeit), in ms.
var _clock_offset := 0.0
var _has_clock_offset := false
var _last_seq_seen := 0
## Host: Prüfung fremder Figuren.
var _check: MovementCheck = null
var _body_material: StandardMaterial3D = null

@onready var _model: Node3D = $Model
@onready var _body: MeshInstance3D = $Model/Body
@onready var _movement_sync: MultiplayerSynchronizer = $MovementSync
@onready var _server_sync: MultiplayerSynchronizer = $ServerSync
@onready var _stats_sync: MultiplayerSynchronizer = $StatsSync
@onready var _stats: CharacterStats = $Stats
@onready var _abilities: PlayerAbilities = $Abilities

## Kleinste Geschwindigkeit, ab der die Figur als „in Bewegung“ gilt.
const MOVING_THRESHOLD := 0.05
## Wie weit beim Stufensteigen nach vorn geprüft wird (Kapselradius), in Metern.
const STEP_PROBE_DISTANCE := 0.4


## Authority vor dem Eintritt der Kindknoten setzen: Die Synchronizer dürfen
## ihre Authority nicht mehr wechseln, sobald sie im Baum sind (sonst kann der
## Spawner den Startzustand nicht zuordnen).
func _enter_tree() -> void:
	if String(name).is_valid_int():
		peer_id = String(name).to_int()
	_apply_authority()


func _ready() -> void:
	floor_max_angle = deg_to_rad(movement.max_slope_deg)
	floor_snap_length = movement.step_height
	floor_constant_speed = true
	floor_stop_on_slope = true
	# Eigene Materialkopie, damit die Klassenfarbe nur diese Figur färbt.
	_body_material = (_body.mesh as PrimitiveMesh).material.duplicate()
	_body.material_override = _body_material
	_stats.stats_changed.connect(_on_stats_changed)
	_update_appearance()
	_on_stats_changed()

	_movement_sync.replication_interval = 1.0 / NETWORK_SETTINGS.sync_rate_hz
	# Figuren nur an Peers senden, die die Welt geladen haben.
	for sync in [_movement_sync, _server_sync, _stats_sync]:
		sync.add_visibility_filter(Network.is_peer_in_world)
	if is_multiplayer_authority():
		_publish_snapshot(_make_snapshot())
	else:
		# Kamera und Eingabe gibt es nur beim Besitzer.
		$CameraRig.queue_free()
		$PlayerInput.queue_free()
		_movement_sync.synchronized.connect(_on_movement_synchronized)
		$Targeting.queue_free()
		$GroundTargeting.queue_free()
		if multiplayer.is_server():
			_check = MovementCheck.new(MOVEMENT_CHECK)


## true, wenn dies die Figur des eigenen Spielers ist.
func is_local() -> bool:
	return is_multiplayer_authority()


## Sendet die Figur ab jetzt auch an Peers, die inzwischen die Welt geladen
## haben (gerufen von GameWorld, wenn sich die Spielerliste ändert).
func refresh_visibility() -> void:
	for sync in [_movement_sync, _server_sync, _stats_sync, $CastSync]:
		if sync.is_multiplayer_authority():
			sync.update_visibility()


## Übernimmt Aussehen, Name und Stufe aus der Spielerliste (Host, vor dem
## Erzeugen bzw. wenn sich etwas ändert).
func setup_from_info(info: NetPlayerInfo) -> void:
	display_name = info.display_name
	race_id = info.race_id
	gender = info.gender
	class_id = info.class_id
	level = info.level


## Werte und Ressourcen der Figur (#19).
func get_stats() -> CharacterStats:
	return _stats


## Fähigkeiten der Figur (#21).
func get_abilities() -> PlayerAbilities:
	return _abilities


## Zielauswahl (#31); nur beim Besitzer, sonst null.
func get_targeting() -> Targeting:
	return get_node_or_null(^"Targeting") as Targeting


## Stufe, mit der die Werte rechnen (inklusive „Stufe ändern“ im
## Entwickler-Panel, das nur zur Laufzeit gilt).
func get_level() -> int:
	return _stats.get_level() if _stats != null and is_node_ready() else level


## Klassendaten der Figur oder null.
func get_class_data() -> ClassData:
	return GameData.get_class_data(class_id)


# --- Einheit (#31) -----------------------------------------------------------

func get_unit_name() -> String:
	return display_name


func is_player_unit() -> bool:
	return true


func get_base_reaction() -> Unit.Reaction:
	return Unit.Reaction.FRIENDLY


func get_stat_class_id() -> StringName:
	return class_id


func get_stat_race_id() -> StringName:
	return race_id


func get_base_level() -> int:
	return level


func get_controlling_peer() -> int:
	return peer_id


## Nur beim Besitzer: Ziel und automatischen Angriff an den Host melden (auf
## dem Host selbst direkt übernehmen). target_path leer = kein Ziel.
func report_target(target: Unit, attack: bool) -> void:
	var path := target.get_path() if target != null else NodePath()
	if multiplayer.is_server():
		_apply_reported_target(path, attack)
	else:
		_rpc_report_target.rpc_id(1, path, attack)


## Wunsch des Besitzers an den Host: Ziel und automatischer Angriff.
@rpc("any_peer", "call_remote", "reliable")
func _rpc_report_target(target_path: NodePath, attack: bool) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != peer_id:
		return
	_apply_reported_target(target_path, attack)


## Host: Ziel übernehmen. Angreifen geht nur bei Einheiten, die die Figur
## angreifen darf (feindlich oder neutral).
func _apply_reported_target(target_path: NodePath, attack: bool) -> void:
	current_target = Unit.from_path(get_tree(), target_path)
	auto_attacking = attack and current_target != null and current_target.can_be_attacked_by(self)


## Authority der Figur = Besitzer; ServerSync gehört immer dem Host.
func _apply_authority() -> void:
	set_multiplayer_authority(peer_id)
	$ServerSync.set_multiplayer_authority(1)
	$StatsSync.set_multiplayer_authority(1)
	$CastSync.set_multiplayer_authority(1)


## Platzhaltermodell: Größe nach Volk, Farbe nach Klasse (ClassData.color,
## siehe UI-Styleguide „Klassenfarben“). Das Geschlecht ändert am Platzhalter
## nichts, wie in der Charaktervorschau.
func _update_appearance() -> void:
	if not is_node_ready():
		return
	var race := GameData.get_race(race_id)
	var factor := race.height_factor if race != null else 1.0
	_model.scale = Vector3.ONE * factor
	var class_data := get_class_data()
	if class_data != null:
		_body_material.albedo_color = class_data.color
	# Klasse, Volk oder Stufe geändert: Werte neu rechnen.
	_stats.refresh_from_unit()
	unit_changed.emit()


## Werte haben sich geändert: Laufgeschwindigkeit (Eile) und Stufe übernehmen.
func _on_stats_changed() -> void:
	speed_multiplier = _stats.get_value(&"movement_speed") / 100.0
	unit_changed.emit()


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


## Setzt die Figur sofort an eine Stelle, z. B. Teleport im Entwickler-Panel
## oder Wiedereinstieg (#15). Übernommen wird nur die Drehung um die
## Hochachse; Schwung und Fallgeschwindigkeit verfallen. Nur auf der Instanz
## mit Authority aufrufen; der MultiplayerSynchronizer (#30) überträgt die
## neue Position an die anderen.
func teleport_to(target: Transform3D) -> void:
	var forward := -target.basis.z
	global_position = target.origin
	rotation = Vector3(0.0, atan2(-forward.x, -forward.z), 0.0)
	velocity = Vector3.ZERO
	_air_velocity = Vector3.ZERO
	_jump_requested = false
	if is_multiplayer_authority():
		net_teleport_seq += 1
		# Wartende Schnappschüsse von vor dem Teleport verwerfen.
		_outgoing.clear()
		_publish_snapshot(_make_snapshot())


## Nur auf dem Host: setzt die Figur an target. Die eigene Figur des Hosts
## springt sofort; bei fremden Figuren bekommt der Besitzer den Befehl, und
## die Bewegungsprüfung erwartet die Figur am Ziel.
func server_teleport(target: Transform3D) -> void:
	if not multiplayer.is_server():
		push_warning("PlayerCharacter.server_teleport: nur der Host darf teleportieren.")
		return
	if is_multiplayer_authority():
		teleport_to(target)
		return
	if _check != null:
		_check.expect_teleport(target.origin)
	_rpc_apply_teleport.rpc_id(peer_id, target)


## Befehl des Hosts an den Besitzer: an target setzen.
@rpc("any_peer", "call_remote", "reliable")
func _rpc_apply_teleport(target: Transform3D) -> void:
	if multiplayer.get_remote_sender_id() != 1 or not is_multiplayer_authority():
		return
	teleport_to(target)


## Dreht die Figur um die Hochachse (Bogenmaß, positiv = nach links). Betäubt
## oder umgeworfen (#32) dreht sie sich nicht.
func add_yaw(radians: float) -> void:
	var combat := get_combat()
	if combat != null and not combat.can_turn():
		return
	rotation.y = wrapf(rotation.y + radians, -PI, PI)


## Host: Effekt „Bewegung“ (#32) setzt die Figur über den Teleport-Weg, damit
## Besitzer und Bewegungsprüfung Bescheid wissen.
func host_move_to(target: Transform3D) -> void:
	server_teleport(target)


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	if turn_input != 0.0:
		add_yaw(turn_input * deg_to_rad(movement.turn_speed_deg) * delta)

	# Zustände aus Auren (#32): betäubt, festgehalten, umgeworfen = keine
	# Bewegung und kein Sprung (übertragen vom Host, gelesen beim Besitzer).
	var combat := get_combat()
	var can_move := combat == null or combat.can_move()
	var jumping := false
	if is_on_floor():
		# Am Boden folgt die Bewegung direkt der Eingabe.
		_air_velocity = _ground_velocity() if can_move else Vector3.ZERO
		velocity.x = _air_velocity.x
		velocity.z = _air_velocity.z
		velocity.y = 0.0
		if _jump_requested and can_move:
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
	if not is_on_floor():
		move_state = MoveState.JUMPING if velocity.y > 0.0 else MoveState.FALLING
	else:
		move_state = MoveState.RUNNING if is_moving else MoveState.STANDING
	_queue_snapshot()


# --- Netzwerk: Besitzer ------------------------------------------------------

func _make_snapshot() -> Dictionary:
	return {
		"time": Time.get_ticks_msec(),
		"position": global_position,
		"yaw": rotation.y,
		"state": move_state,
		"seq": net_teleport_seq,
	}


## Merkt den aktuellen Stand vor und veröffentlicht den neuesten, der älter
## als die künstliche Verzögerung ist (ohne Verzögerung: sofort).
func _queue_snapshot() -> void:
	_outgoing.append(_make_snapshot())
	var cutoff := Time.get_ticks_msec() - Network.artificial_delay_ms
	var ready_snapshot: Dictionary = {}
	while not _outgoing.is_empty() and _outgoing[0]["time"] <= cutoff:
		ready_snapshot = _outgoing.pop_front()
	if not ready_snapshot.is_empty():
		_publish_snapshot(ready_snapshot)


func _publish_snapshot(snapshot: Dictionary) -> void:
	net_time = snapshot["time"]
	net_position = snapshot["position"]
	net_yaw = snapshot["yaw"]
	net_state = snapshot["state"]
	net_teleport_seq = snapshot["seq"]


# --- Netzwerk: andere Instanzen ----------------------------------------------

## MovementSync hat einen neuen Schnappschuss des Besitzers empfangen.
func _on_movement_synchronized() -> void:
	var snapshot := {
		"time": net_time,
		"position": net_position,
		"yaw": net_yaw,
		"state": net_state,
		"seq": net_teleport_seq,
	}
	if _check != null and not _host_check(snapshot):
		return
	# Uhrenabstand: steigt schnell (Verbindung langsamer geworden), sinkt
	# langsam (gegen Ausreißer bei schwankender Laufzeit).
	var sample := Time.get_ticks_usec() / 1000.0 - net_time
	if not _has_clock_offset:
		_clock_offset = sample
		_has_clock_offset = true
	else:
		_clock_offset = lerpf(_clock_offset, sample, 0.2 if sample > _clock_offset else 0.02)
	if net_teleport_seq != _last_seq_seen:
		# Teleport: nicht durch die Welt gleiten, sondern springen.
		_last_seq_seen = net_teleport_seq
		_snapshots.clear()
		_apply_snapshot(snapshot)
	elif not _snapshots.is_empty() and net_time <= _snapshots[-1]["time"]:
		return  # Veraltet oder doppelt.
	_snapshots.append(snapshot)
	# Mehr als ca. 1 s Vorrat braucht die Interpolation nicht.
	while _snapshots.size() > int(NETWORK_SETTINGS.sync_rate_hz) + 2:
		_snapshots.pop_front()


## Host: Plausibilität prüfen. false = Meldung verworfen.
func _host_check(snapshot: Dictionary) -> bool:
	var result := _check.check(snapshot["position"], snapshot["yaw"], snapshot["time"],
			snapshot["seq"], movement, get_run_speed())
	if result == MovementCheck.Result.OK:
		return true
	if result == MovementCheck.Result.VIOLATION:
		var target := _check.get_last_valid_transform()
		push_warning("Bewegungsprüfung: %s (Peer %d) unplausibel bei %s, zurück nach %s." % [
				display_name, peer_id, snapshot["position"], target.origin])
		_check.expect_teleport(target.origin)
		_rpc_apply_teleport.rpc_id(peer_id, target)
		_snapshots.clear()
		_apply_snapshot({"position": target.origin, "yaw": snapshot["yaw"], "state": MoveState.STANDING})
	return false


## Fremde Figuren weich zwischen zwei Schnappschüssen darstellen. Läuft pro
## Bild (nicht im Physiktakt), damit es auch über 60 Hz nicht ruckelt.
func _process(_delta: float) -> void:
	if is_multiplayer_authority() or _snapshots.is_empty():
		return
	# Mikrosekunden statt Millisekunden: über 60 Hz liegen Bilder nur wenige ms
	# auseinander, ganze ms würden die Bewegung sichtbar stufen.
	var now_ms := Time.get_ticks_usec() / 1000.0
	var render_time := now_ms - _clock_offset - NETWORK_SETTINGS.interpolation_delay_ms
	var older: Dictionary = _snapshots[0]
	var newer: Dictionary = {}
	for snapshot in _snapshots:
		if snapshot["time"] <= render_time:
			older = snapshot
		else:
			newer = snapshot
			break
	if newer.is_empty():
		_apply_snapshot(older)  # Nichts Neueres da: am letzten Stand warten.
		return
	if render_time <= older["time"]:
		_apply_snapshot(older)  # Puffer läuft gerade an.
		return
	var t := clampf((render_time - older["time"]) / float(newer["time"] - older["time"]), 0.0, 1.0)
	global_position = (older["position"] as Vector3).lerp(newer["position"], t)
	rotation = Vector3(0.0, lerp_angle(older["yaw"], newer["yaw"], t), 0.0)
	_set_remote_state(older["state"])


func _apply_snapshot(snapshot: Dictionary) -> void:
	global_position = snapshot["position"]
	rotation = Vector3(0.0, snapshot["yaw"], 0.0)
	_set_remote_state(snapshot["state"])


func _set_remote_state(state: int) -> void:
	move_state = state as MoveState
	is_moving = move_state != MoveState.STANDING


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
