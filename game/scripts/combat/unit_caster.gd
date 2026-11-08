class_name UnitCaster
extends Node
## Fähigkeiten wirken (Ticket #33): Prüfungen, Zauberzeit, Kanalisieren,
## globaler Cooldown, Abklingzeiten, Aufladungen, Kosten, Zauber-Warteschlange,
## Unterbrechen, nächster Schlag und automatischer Angriff. Kindknoten
## „Caster“ jeder Unit (Spielfiguren, Übungspuppen, später Gegner).
##
## Ablauf beim Einsetzen (check, in dieser Reihenfolge, wie im Ticket):
##   1. Fähigkeit bekannt und in der aktuellen Gestalt verfügbar
##   2. lebt, nicht betäubt/umgeworfen, nicht still (Zauber), Schule nicht
##      gesperrt, nicht bereits am Zaubern
##   3. Abklingzeit (bzw. Aufladung) und globaler Cooldown frei
##   4. genug Ressource
##   5. gültiges Ziel (Hilfszauber ohne passendes Ziel: auf sich selbst)
##   6. Reichweite und Sichtlinie
##   7. Ziel vor dem Wirker
##   8. Waffe, Tarnung, hinter dem Ziel, im Stand (Zauberzeit), Aura
## Danach beginnt die Fähigkeit: sofort (Kosten, Abklingzeit, Effekte),
## Zauberzeit (Kosten und Abklingzeit am Ende, vorher erneut Ziel,
## Reichweite, Sichtlinie und Ressource prüfen) oder Kanalisieren (Kosten und
## Abklingzeit am Anfang, Effekte je Tick). Abbruch oder Unterbrechung:
## keine Kosten.
##
## Netzwerk – der Host entscheidet:
## - Der Besitzer einer Spielfigur prüft selbst mit denselben Daten (check)
##   und zeigt Zauberleiste, globalen Cooldown und Abklingzeit sofort an
##   (Vorhersage). Dann schickt er den Wunsch per RPC an den Host
##   (_rpc_use, mit eigener Position und Blickrichtung, weil er seine Figur
##   selbst bewegt). Die künstliche Verzögerung aus dem Entwickler-Panel
##   (#30) hält auch diese Wünsche zurück.
## - Der Host prüft erneut, führt aus und antwortet (_rpc_result). Lehnt er
##   ab, bricht der Besitzer die Vorhersage ab und zeigt die Meldung.
## - Zustand für alle überträgt „CastSync“ (Authority Host, bei Änderung):
##   cast_state (laufender Zauber mit Start und Ende in Host-Zeit),
##   cast_end (Ergebnis des letzten Zaubers: fertig, unterbrochen,
##   abgebrochen, fehlgeschlagen), cooldown_state (globaler Cooldown,
##   Abklingzeiten, Aufladungen, gesperrte Schulen, nächster Schlag) und
##   auto_attack_on. Restzeiten rechnen alle aus Network.host_time().
## - Zauber-Warteschlange: Der Besitzer merkt sich einen Wunsch, der bis zu
##   zauber_warteschlange Sekunden vor Ende von globalem Cooldown, Zauber
##   oder Abklingzeit kommt, und schickt ihn, sobald es geht. Der Host
##   wartet ebenso kurz, bevor er wegen „noch nicht bereit“ ablehnt
##   (gleicht Laufzeitschwankungen aus).
## - Bewegung meldet der Besitzer (er bewegt die Figur selbst): Beginnt er
##   sich zu bewegen, bricht er Zauber ab und schickt das an den Host. Der
##   Host prüft grob nach (gemeldete Position weit vom Startpunkt).
## - Automatischer Angriff läuft nur auf dem Host (Unit.auto_attacking);
##   auto_attack_on zeigt dem Besitzer, wenn der Host ihn beendet.

## Laufender Zauber hat sich geändert (Beginn, Verzögerung, Ende).
signal cast_changed
## Ein Zauber ist zu Ende (Result.*); für Zauberleisten aller Spieler.
signal cast_ended(result: int, ability_id: StringName)
## Globaler Cooldown, Abklingzeiten, Aufladungen oder Sperren geändert.
signal cooldowns_changed
## Nur beim Besitzer: eine Fähigkeit ging nicht (AbilityError.Code, Zusatz).
signal failed(code: int, param: String, ability: AbilityData)
## Nur beim Besitzer: ein Wunsch wurde abgeschickt.
signal requested(ability: AbilityData)
## Automatischer Angriff laut Host an oder aus.
signal auto_attack_changed(active: bool)

enum Result { DONE, INTERRUPTED, CANCELLED, FAILED }

const NODE_NAME := "Caster"
## Der Host wartet so viel länger als die Warteschlange (Laufzeitschwankung).
const HOST_QUEUE_SLACK := 0.25
## Ein vorhergesagter Zauber gilt beim Besitzer so lange nach seinem Ende
## noch als laufend, bis der Host antwortet (Sicherheitsgrenze, Sekunden).
const PREDICTION_TIMEOUT := 3.0
## Gemeldete Position darf so weit von der zuletzt bekannten abweichen.
const MAX_REPORTED_OFFSET := 4.0
## Ein Fehler des automatischen Angriffs geht höchstens so oft an den Besitzer.
const AUTO_ERROR_INTERVAL := 1.0

## Übertragen (Host → alle): [Fähigkeit, Start, Ende, kanalisiert,
## unterbrechbar, Schule, Zielpfad, Wunsch-Nummer] oder leer.
var cast_state: Array = []:
	set(value):
		cast_state = value
		cast_changed.emit()
## Übertragen: [laufende Nummer, Wunsch-Nummer, Result, Fähigkeit].
var cast_end: Array = []:
	set(value):
		cast_end = value
		_on_cast_end_received()
## Übertragen: {"gcd": [Start, Ende], "cd": {Schlüssel: [Start, Ende]},
## "ch": {Fähigkeit: [Ladungen, nächste fertig, Dauer, Höchstzahl]},
## "lock": {Schule: Ende}, "next": Fähigkeit des nächsten Schlags}.
var cooldown_state: Dictionary = {}:
	set(value):
		cooldown_state = value
		cooldowns_changed.emit()
## Übertragen: automatischer Angriff läuft (Host).
var auto_attack_on := false:
	set(value):
		if value == auto_attack_on:
			return
		auto_attack_on = value
		auto_attack_changed.emit(value)

var _unit: Unit = null
var _last_end_seq := 0
var _glow: MeshInstance3D = null
var _glow_material: StandardMaterial3D = null
var _glow_school: StringName = &""

# --- nur Host ---
var _cast: Dictionary = {}
var _gcd: Array = [0.0, 0.0]
var _cooldowns: Dictionary = {}
var _charges: Dictionary = {}
var _locks: Dictionary = {}
var _queue: Dictionary = {}
var _next_swing: Dictionary = {}
var _main_at := 0.0
var _off_at := 0.0
var _ranged_at := 0.0
var _end_seq := 0
var _cd_dirty := false
var _auto_errors: Dictionary = {}

# --- nur Besitzer (Vorhersage) ---
var _req_seq := 0
var _pending: Dictionary = {}
var _pred_gcd: Array = []
var _pred_cd: Dictionary = {}
var _pred_charges: Dictionary = {}
var _pred_cast: Dictionary = {}
var _client_queue: Dictionary = {}
## Wunsch-Nummer eines Zaubers, den der Besitzer selbst beendet hat (Ende
## vom Host dann nicht noch einmal melden).
var _locally_ended_req := -1
## Wunsch-Nummern, deren Vorhersage beendet bzw. abgelehnt wurde (die letzten).
var _dropped_reqs: Array[int] = []


func _enter_tree() -> void:
	_unit = get_parent() as Unit


func _ready() -> void:
	var sync := get_parent().get_node_or_null(^"CastSync") as MultiplayerSynchronizer
	if sync != null:
		# Authority Host setzt die Einheit in _enter_tree (vor dem Eintritt).
		sync.add_visibility_filter(Network.is_peer_in_world)
	if _unit == null:
		return
	var combat := _unit.get_combat()
	if combat != null:
		combat.states_changed.connect(_on_states_changed)
	if _unit is PlayerCharacter:
		(_unit as PlayerCharacter).moving_changed.connect(_on_moving_changed)
	cast_changed.connect(_update_glow)


func _process(_delta: float) -> void:
	if _unit == null:
		return
	if Network.is_host():
		_host_process()
	if is_owner() and not Network.is_host():
		_owner_process()
	elif is_owner():
		_process_client_queue()


# --- Lesen (überall) ---------------------------------------------------------

func get_unit() -> Unit:
	return _unit


## true auf der Instanz, der diese Spielfigur gehört.
func is_owner() -> bool:
	return _unit != null and _unit.is_player_unit() and _unit.get_controlling_peer() == multiplayer.get_unique_id()


## Laufender Zauber zum Anzeigen: {ability, start, end, channel,
## interruptible, school, target_path, req} oder leer. Beim Besitzer die
## Vorhersage, sonst der Stand des Hosts.
func get_cast_info() -> Dictionary:
	if not _pred_cast.is_empty():
		return _pred_cast
	var info := _parse_cast(cast_state)
	# Beim Besitzer: selbst beendete oder abgelehnte Zauber nicht wieder zeigen,
	# bis der Host sie ebenfalls beendet hat.
	if not info.is_empty() and is_owner() and not Network.is_host() and _dropped_reqs.has(int(info["req"])):
		return {}
	return info


## Zaubert gerade (für Prüfungen: Vorhersage endet beim Besitzer zur
## vorhergesagten Zeit, damit die Warteschlange ohne Laufzeit-Verlust greift).
func is_casting() -> bool:
	if Network.is_host():
		return not _cast.is_empty()
	var info := get_cast_info()
	if info.is_empty():
		return false
	if not _pred_cast.is_empty():
		return Network.host_time() < float(info["end"])
	return true


## Restzeit des laufenden Zaubers (für die Warteschlange).
func get_cast_remaining() -> float:
	if not is_casting():
		return 0.0
	var info := get_cast_info() if not Network.is_host() else _host_cast_info()
	return maxf(0.0, float(info.get("end", 0.0)) - Network.host_time())


## Restzeit und Dauer des globalen Cooldowns.
func get_gcd() -> Vector2:
	var now := Network.host_time()
	var window: Array = _pred_gcd if not _pred_gcd.is_empty() and not Network.is_host() \
			else cooldown_state.get("gcd", [0.0, 0.0])
	if Network.is_host():
		window = _gcd
	var remaining := maxf(0.0, float(window[1]) - now)
	return Vector2(remaining, maxf(0.01, float(window[1]) - float(window[0])))


## Restzeit und Dauer der Abklingzeit einer Fähigkeit (bei Aufladungen: bis
## zur nächsten Ladung, nur wenn keine mehr da ist).
func get_cooldown(ability: AbilityData) -> Vector2:
	if ability == null:
		return Vector2.ZERO
	var now := Network.host_time()
	if ability.get_charges() > 1:
		if get_charges_left(ability) > 0:
			return Vector2.ZERO
		var entry := _charge_entry(ability)
		return Vector2(maxf(0.0, float(entry[1]) - now), maxf(0.01, float(entry[2])))
	var key := String(ability.get_cooldown_key())
	var best := Vector2.ZERO
	var windows: Array = []
	if Network.is_host():
		windows.append(_cooldowns.get(key, []))
	else:
		windows.append((cooldown_state.get("cd", {}) as Dictionary).get(key, []))
		windows.append(_pred_cd.get(key, []))
	for window: Array in windows:
		if window.size() >= 2 and float(window[1]) - now > best.x:
			best = Vector2(float(window[1]) - now, maxf(0.01, float(window[1]) - float(window[0])))
	return best


## Verfügbare Aufladungen (bei Fähigkeiten ohne Aufladungen 1 bzw. 0).
func get_charges_left(ability: AbilityData) -> int:
	var maximum := ability.get_charges()
	if maximum <= 1:
		return 0 if get_cooldown(ability).x > 0.0 else 1
	var entry := _charge_entry(ability)
	var count := int(entry[0])
	# Ladungen, die laut Zeit schon wieder da sind (Stand kann älter sein).
	var now := Network.host_time()
	var next_ready := float(entry[1])
	var duration := float(entry[2])
	while count < maximum and next_ready > 0.0 and now >= next_ready:
		count += 1
		next_ready += duration
	if not Network.is_host():
		count -= int(_pred_charges.get(String(ability.id), [0])[0])
	return clampi(count, 0, maximum)


## Sperre einer Schule nach Unterbrechung: Restzeit (0 = frei).
func get_school_lock(school: StringName) -> float:
	var locks: Dictionary = _locks if Network.is_host() else cooldown_state.get("lock", {})
	return maxf(0.0, float(locks.get(String(school), 0.0)) - Network.host_time())


## Fähigkeit des vorgemerkten nächsten Schlags (leer = keine).
func get_next_swing_id() -> StringName:
	if Network.is_host():
		return _next_swing["ability"].id if not _next_swing.is_empty() else &""
	return StringName(str(cooldown_state.get("next", "")))


## Zeit, bis die Fähigkeit wieder eingesetzt werden könnte (Zauber,
## globaler Cooldown, Abklingzeit), für die Warteschlange.
func get_wait_time(ability: AbilityData) -> float:
	var wait := get_cast_remaining()
	if not ability.ignores_gcd:
		wait = maxf(wait, get_gcd().x)
	if ability.get_charges() <= 1 or get_charges_left(ability) <= 0:
		wait = maxf(wait, get_cooldown(ability).x)
	return wait


## Globaler Cooldown dieser Einheit in Sekunden (gcd / Tempo, mindestens gcd_min).
func get_gcd_duration() -> float:
	return maxf(Data.konstante(&"gcd_min", 0.75), Data.konstante(&"gcd", 1.5) / _haste_factor())


## Zauberzeit mit Tempo und Veränderungen durch Talente/Auren.
func get_cast_time(ability: AbilityData) -> float:
	return maxf(0.0, ability.get_number_for(_unit, "zauberzeit")) / _haste_factor()


func get_channel_time(ability: AbilityData) -> float:
	return maxf(0.0, ability.get_number_for(_unit, "kanalisierzeit")) / _haste_factor()


func get_cast_type(ability: AbilityData) -> AbilityData.CastType:
	if get_channel_time(ability) > 0.0:
		return AbilityData.CastType.CHANNELED
	if get_cast_time(ability) > 0.0:
		return AbilityData.CastType.CAST
	return AbilityData.CastType.INSTANT


## Reichweite in Metern (Rand zu Rand); 0 in der Tabelle = Nahkampf.
func get_range(ability: AbilityData) -> float:
	var value := ability.get_number_for(_unit, "reichweite")
	if value <= 0.0 and ability.target_kind != AbilityData.TargetKind.NONE:
		return Data.konstante(&"nahkampf_reichweite", 5.0)
	return value


## Kosten mit Veränderungen.
func get_cost(ability: AbilityData) -> float:
	return maxf(0.0, ability.get_number_for(_unit, "kosten"))


## Genug Ressource für die Fähigkeit?
func has_resource_for(ability: AbilityData) -> bool:
	var resource := ability.get_cost_resource()
	var cost := get_cost(ability)
	if resource == &"" or cost <= 0.0:
		return true
	var stats := _unit.get_stats()
	return stats != null and stats.get_resource(resource) >= cost - 0.001


## Ziel im Bereich (nur Entfernung, für die Tönung der Aktionsleiste).
## true, wenn kein Ziel nötig ist oder keins gewählt ist.
func is_in_range(ability: AbilityData, target: Unit) -> bool:
	if ability.target_kind in [AbilityData.TargetKind.NONE, AbilityData.TargetKind.GROUND]:
		return true
	if target == null or not is_instance_valid(target) or target == _unit:
		return true
	if ability.targets_friends() and _unit.get_reaction_to(target) != Unit.Reaction.FRIENDLY:
		return true
	return _distance_from(_unit.global_position, target) <= get_range(ability) + 0.001


# --- Prüfen ------------------------------------------------------------------

## Prüft, ob die Fähigkeit jetzt geht. Gibt [AbilityError.Code, Zusatz,
## aufgelöstes Ziel] zurück. view: {"pos", "facing", "moving"} des Wirkers
## (leer = eigene Werte dieser Instanz).
func check(ability: AbilityData, target: Unit, point := Vector3.ZERO, has_point := false,
		view: Dictionary = {}) -> Array:
	if view.is_empty():
		view = _local_view()
	var combat := _unit.get_combat()
	# 1. Bekannt und verfügbar
	if _unit is PlayerCharacter:
		var abilities := (_unit as PlayerCharacter).get_abilities()
		if abilities != null and not abilities.knows(ability):
			return _fail(AbilityError.Code.NOT_LEARNED)
	# 2. Zustand
	if _unit.is_dead():
		return _fail(AbilityError.Code.DEAD)
	if combat != null and not combat.can_act():
		return _fail(AbilityError.Code.CANNOT_ACT)
	if ability.is_spell and combat != null and combat.has_state(Combat.STATE_SILENCED):
		return _fail(AbilityError.Code.SILENCED)
	if ability.is_spell and get_school_lock(ability.get_school()) > 0.0:
		return _fail(AbilityError.Code.SCHOOL_LOCKED, String(ability.get_school()))
	if is_casting():
		return _fail(AbilityError.Code.BUSY)
	# 3. Abklingzeit und globaler Cooldown
	if not ability.ignores_gcd and get_gcd().x > 0.0:
		return _fail(AbilityError.Code.NOT_READY)
	if ability.get_charges() > 1:
		if get_charges_left(ability) <= 0:
			return _fail(AbilityError.Code.NOT_READY)
	elif get_cooldown(ability).x > 0.0:
		return _fail(AbilityError.Code.NOT_READY)
	if ability.on_next_swing and get_next_swing_id() != &"":
		return _fail(AbilityError.Code.NOT_READY)
	# 4. Ressource
	if not has_resource_for(ability):
		return _fail(AbilityError.Code.NO_RESOURCE, String(ability.get_cost_resource()))
	# 5. Ziel
	var resolved := _resolve_target(ability, target)
	if resolved[0] != AbilityError.Code.OK:
		return resolved
	var unit_target: Unit = resolved[2]
	if ability.target_kind == AbilityData.TargetKind.GROUND and not has_point:
		return _fail(AbilityError.Code.INVALID_POINT)
	# 6. Reichweite und Sichtlinie
	var range_check := _check_range(ability, unit_target, point, has_point, view)
	if range_check != AbilityError.Code.OK:
		return _fail(range_check)
	# 7. Blickrichtung
	if ability.requires_facing and ability.target_kind == AbilityData.TargetKind.ENEMY \
			and unit_target != null and unit_target != _unit \
			and not _is_facing(view, unit_target):
		return _fail(AbilityError.Code.NOT_FACING)
	# 8. Besondere Bedingungen
	if not _has_weapon(ability.required_weapon):
		return _fail(AbilityError.Code.NEED_WEAPON, str(ability.required_weapon))
	if ability.requires_stealth and not _unit.is_stealthed():
		return _fail(AbilityError.Code.NEED_STEALTH)
	if ability.requires_behind and (unit_target == null or unit_target == _unit \
			or not _is_behind(view, unit_target)):
		return _fail(AbilityError.Code.NEED_BEHIND)
	if ability.required_aura != &"" and (combat == null or combat.get_stacks(ability.required_aura) <= 0):
		return _fail(AbilityError.Code.NEED_AURA, String(ability.required_aura))
	if bool(view.get("moving", false)) and not ability.castable_while_moving \
			and get_cast_type(ability) != AbilityData.CastType.INSTANT:
		return _fail(AbilityError.Code.MOVING)
	return [AbilityError.Code.OK, "", unit_target]


# --- Einsetzen (Besitzer bzw. Host) ------------------------------------------

## Fähigkeit einsetzen (Besitzer der Figur, über PlayerAbilities). Prüft
## sofort, zeigt die Vorhersage und schickt den Wunsch an den Host. Auf dem
## Host (bzw. offline) wird direkt ausgeführt.
func request_use(ability: AbilityData, target: Unit, point := Vector3.ZERO, has_point := false) -> void:
	if ability == null or _unit == null:
		return
	ability = ability.get_replacement_for(_unit)
	_client_queue = {}
	if _is_toggle_off(ability):
		_send(ability, target, point, has_point, false)
		return
	var result := check(ability, target, point, has_point)
	var code: int = result[0]
	if code != AbilityError.Code.OK:
		if AbilityError.is_queueable(code) \
				and get_wait_time(ability) <= Data.konstante(&"zauber_warteschlange", 0.4):
			_client_queue = {"ability": ability, "target": target, "point": point,
					"has_point": has_point, "until": Network.host_time() + get_wait_time(ability) + 0.5}
			return
		_owner_fail(code, result[1], ability)
		return
	_send(ability, result[2] if result[2] != null else target, point, has_point, true)


## Laufenden eigenen Zauber abbrechen (Esc, Bewegung). Gibt true zurück,
## wenn etwas lief.
func request_cancel(reason: int = AbilityError.Code.OK) -> bool:
	if not is_owner():
		return false
	_client_queue = {}
	var info := get_cast_info()
	if info.is_empty():
		return false
	if not Network.is_host():
		var ability: AbilityData = info["ability"]
		_locally_ended_req = int(info["req"])
		_drop_req(_locally_ended_req)
		_pred_cast = {}
		cast_changed.emit()
		cast_ended.emit(Result.CANCELLED, ability.id)
	if reason != AbilityError.Code.OK:
		_owner_fail(reason, "", null)
	if Network.is_host():
		host_cancel(Result.CANCELLED)
	else:
		_send_delayed(func() -> void: _rpc_cancel.rpc_id(1, reason))
	return true


# --- Host --------------------------------------------------------------------

## Host: Fähigkeit für diese Einheit ausführen (Spieler über _rpc_use, KI und
## Übungspuppen direkt). Gibt [Code, Zusatz] zurück; Code −1 = in der
## Warteschlange des Hosts (Antwort folgt).
func host_use(ability: AbilityData, target: Unit, point := Vector3.ZERO, has_point := false,
		req_id := 0, peer := 0, view: Dictionary = {}, allow_queue := true) -> Array:
	if not Network.is_host() or ability == null:
		return [AbilityError.Code.INVALID_TARGET, ""]
	ability = ability.get_replacement_for(_unit)
	if ability.toggles_auto_attack:
		_toggle_auto_attack(target)
		return [AbilityError.Code.OK, ""]
	if _is_toggle_off(ability):
		_unit.get_combat().remove_aura(ability.toggle_aura.id, _unit)
		return [AbilityError.Code.OK, ""]
	var result := check(ability, target, point, has_point, view)
	var code: int = result[0]
	if code != AbilityError.Code.OK:
		var window := Data.konstante(&"zauber_warteschlange", 0.4) + HOST_QUEUE_SLACK
		if allow_queue and peer != 0 and AbilityError.is_queueable(code) and get_wait_time(ability) <= window:
			if not _queue.is_empty():
				_send_result(int(_queue["peer"]), int(_queue["req"]), AbilityError.Code.NOT_READY, "")
			_queue = {"ability": ability, "target": target, "point": point, "has_point": has_point,
					"req": req_id, "peer": peer, "view": view, "until": Network.host_time() + window,
					"code": code}
			return [-1, ""]
		return [code, result[1]]
	var unit_target: Unit = result[2]
	var now := Network.host_time()
	if ability.on_next_swing:
		_next_swing = {"ability": ability, "target": unit_target, "req": req_id, "peer": peer}
		_start_auto_attack(unit_target)
		if not ability.ignores_gcd:
			_gcd = [now, now + get_gcd_duration()]
		_cd_dirty = true
		return [AbilityError.Code.OK, ""]
	if not ability.ignores_gcd:
		_gcd = [now, now + get_gcd_duration()]
		_cd_dirty = true
	if ability.starts_auto_attack:
		_start_auto_attack(unit_target)
	var cast_type := get_cast_type(ability)
	match cast_type:
		AbilityData.CastType.INSTANT:
			_pay_cost(ability)
			_start_cooldown(ability)
			_apply(ability, unit_target, point, has_point)
		AbilityData.CastType.CAST:
			_begin_cast(ability, unit_target, point, has_point, req_id, peer, view, false)
		AbilityData.CastType.CHANNELED:
			_pay_cost(ability)
			_start_cooldown(ability)
			_begin_cast(ability, unit_target, point, has_point, req_id, peer, view, true)
	return [AbilityError.Code.OK, ""]


## Host: laufenden Zauber abbrechen (ohne Kosten).
func host_cancel(result: int = Result.CANCELLED, code: int = AbilityError.Code.OK) -> bool:
	if not Network.is_host() or _cast.is_empty():
		return false
	if result != Result.INTERRUPTED and code == AbilityError.Code.OK:
		_queue = {}
	_end_cast(result, code)
	return true


## Host: Unterbrechung (Effekt „Unterbrechen“). Stoppt einen unterbrechbaren
## Zauber und sperrt seine Schule lock_duration Sekunden. Gibt true zurück,
## wenn etwas unterbrochen wurde.
func interrupt(lock_duration: float) -> bool:
	if not Network.is_host() or _cast.is_empty():
		return false
	var ability: AbilityData = _cast["ability"]
	if not ability.interruptible:
		return false
	if lock_duration > 0.0:
		_locks[String(ability.get_school())] = Network.host_time() + lock_duration
		_cd_dirty = true
	_end_cast(Result.INTERRUPTED, AbilityError.Code.INTERRUPTED)
	return true


## Host: Die Einheit hat Schaden genommen (Combat.deal_damage). Verzögert
## einen Zauber mit Zauberzeit um zauber_verzoegerung Sekunden, höchstens
## zauber_verzoegerung_max mal. Kanalisieren wird nicht verzögert.
func on_damage_taken() -> void:
	if not Network.is_host() or _cast.is_empty() or bool(_cast["channel"]):
		return
	if int(_cast["pushbacks"]) >= int(Data.konstante(&"zauber_verzoegerung_max", 2.0)):
		return
	_cast["pushbacks"] = int(_cast["pushbacks"]) + 1
	_cast["end"] = float(_cast["end"]) + Data.konstante(&"zauber_verzoegerung", 0.5)
	_publish_cast()


## Host: Abklingzeiten zurücksetzen (Entwickler-Panel).
func host_reset_cooldowns() -> void:
	if not Network.is_host():
		return
	_cooldowns.clear()
	_charges.clear()
	_locks.clear()
	_gcd = [0.0, 0.0]
	_cd_dirty = true


# --- Netzwerk ----------------------------------------------------------------

## Entwickler-Panel: eigene Abklingzeiten zurücksetzen (Wunsch an den Host).
func request_reset_cooldowns() -> void:
	if Network.is_host():
		host_reset_cooldowns()
	else:
		_rpc_reset_cooldowns.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_reset_cooldowns() -> void:
	if Network.is_host() and OS.is_debug_build() and _unit != null 			and multiplayer.get_remote_sender_id() == _unit.get_controlling_peer():
		host_reset_cooldowns()


@rpc("any_peer", "call_remote", "reliable")
func _rpc_use(req_id: int, ability_id: String, target_path: NodePath, point: Vector3,
		has_point: bool, pos: Vector3, yaw: float, moving: bool) -> void:
	if not Network.is_host() or _unit == null:
		return
	var peer := multiplayer.get_remote_sender_id()
	if peer != _unit.get_controlling_peer():
		return
	var ability := GameData.get_ability(StringName(ability_id))
	if ability == null:
		_send_result(peer, req_id, AbilityError.Code.NOT_LEARNED, "")
		return
	var view := _remote_view(pos, yaw, moving)
	var result := host_use(ability, Unit.from_path(get_tree(), target_path), point, has_point,
			req_id, peer, view)
	if int(result[0]) >= 0:
		_send_result(peer, req_id, int(result[0]), str(result[1]))


@rpc("any_peer", "call_remote", "reliable")
func _rpc_cancel(reason: int) -> void:
	if not Network.is_host() or _unit == null:
		return
	if multiplayer.get_remote_sender_id() != _unit.get_controlling_peer():
		return
	_queue = {}
	# Der Besitzer hat die Meldung schon selbst gezeigt.
	host_cancel(Result.CANCELLED)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_result(req_id: int, code: int, param: String) -> void:
	if multiplayer.get_remote_sender_id() == 1:
		_on_result(req_id, code, param)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_error(code: int, param: String) -> void:
	if multiplayer.get_remote_sender_id() == 1:
		_owner_fail(code, param, null)


# --- Intern: Host ------------------------------------------------------------

func _host_process() -> void:
	var now := Network.host_time()
	_recharge(now)
	if not _cast.is_empty():
		_process_cast(now)
	if not _queue.is_empty():
		_process_host_queue(now)
	_process_auto_attack(now)
	var on := _unit.auto_attacking and _unit.current_target != null
	if auto_attack_on != on:
		auto_attack_on = on
	if _cd_dirty:
		_publish_cooldowns()


func _process_cast(now: float) -> void:
	var ability: AbilityData = _cast["ability"]
	var target: Unit = _cast["target"] if is_instance_valid(_cast["target"]) else null
	# Grobe Bewegungsprüfung fremder Figuren (Besitzer meldet den Abbruch selbst).
	if not ability.castable_while_moving and _moved_since_start():
		_end_cast(Result.CANCELLED, AbilityError.Code.MOVING)
		return
	if bool(_cast["channel"]):
		if _needs_unit_target(ability) and (target == null or target.is_dead()):
			_end_cast(Result.DONE)
			return
		while not _cast.is_empty() and now >= float(_cast["next_tick"]) \
				and float(_cast["next_tick"]) <= float(_cast["end"]) + 0.001:
			_cast["next_tick"] = float(_cast["next_tick"]) + float(_cast["interval"])
			_apply(ability, target, _cast["point"], _cast["has_point"], true)
		if not _cast.is_empty() and now >= float(_cast["end"]):
			_end_cast(Result.DONE)
		return
	if now < float(_cast["end"]):
		return
	# Ende der Zauberzeit: Ziel, Reichweite, Sichtlinie und Ressource erneut.
	var code := AbilityError.Code.OK
	var param := ""
	if _needs_unit_target(ability):
		if target == null:
			code = AbilityError.Code.INVALID_TARGET
		elif target.is_dead():
			code = AbilityError.Code.TARGET_DEAD
	if code == AbilityError.Code.OK:
		code = _check_range(ability, target, _cast["point"], _cast["has_point"], _host_view())
	if code == AbilityError.Code.OK and not has_resource_for(ability):
		code = AbilityError.Code.NO_RESOURCE
		param = String(ability.get_cost_resource())
	if code != AbilityError.Code.OK:
		_end_cast(Result.FAILED, code, param)
		return
	var run := _cast
	_pay_cost(ability)
	_start_cooldown(ability)
	_end_cast(Result.DONE)
	_apply(ability, target, run["point"], run["has_point"])


func _begin_cast(ability: AbilityData, target: Unit, point: Vector3, has_point: bool,
		req_id: int, peer: int, view: Dictionary, channel: bool) -> void:
	var now := Network.host_time()
	var duration := get_channel_time(ability) if channel else get_cast_time(ability)
	var interval := duration
	if channel:
		var tick := ability.get_number_for(_unit, "tick") / _haste_factor()
		interval = tick if tick > 0.0 else duration
	_cast = {
		"ability": ability, "target": target, "point": point, "has_point": has_point,
		"start": now, "end": now + duration, "channel": channel, "req": req_id, "peer": peer,
		"pushbacks": 0, "interval": interval, "next_tick": now + interval,
		"origin": view.get("pos", _unit.global_position),
	}
	_publish_cast()


func _end_cast(result: int, code: int = AbilityError.Code.OK, param := "") -> void:
	if _cast.is_empty():
		return
	var run := _cast
	_cast = {}
	cast_state = []
	_end_seq += 1
	cast_end = [_end_seq, int(run["req"]), result, String((run["ability"] as AbilityData).id)]
	if code != AbilityError.Code.OK:
		_send_error(int(run["peer"]), code, param)


func _publish_cast() -> void:
	var ability: AbilityData = _cast["ability"]
	var target: Unit = _cast["target"] if is_instance_valid(_cast["target"]) else null
	cast_state = [String(ability.id), float(_cast["start"]), float(_cast["end"]), bool(_cast["channel"]),
			ability.interruptible, String(ability.get_school()),
			target.get_path() if target != null and target.is_inside_tree() else NodePath(),
			int(_cast["req"])]


func _host_cast_info() -> Dictionary:
	if _cast.is_empty():
		return {}
	return {"end": _cast["end"], "start": _cast["start"]}


func _process_host_queue(now: float) -> void:
	var ability: AbilityData = _queue["ability"]
	var peer := int(_queue["peer"])
	var req := int(_queue["req"])
	if now > float(_queue["until"]):
		var code := int(_queue["code"])
		_queue = {}
		_send_result(peer, req, code, "")
		return
	if get_wait_time(ability) > 0.0:
		return
	var entry := _queue
	_queue = {}
	var target: Unit = entry["target"] if is_instance_valid(entry["target"]) else null
	var result := host_use(ability, target, entry["point"], entry["has_point"], req, peer,
			entry["view"], false)
	_send_result(peer, req, int(result[0]), str(result[1]))


func _apply(ability: AbilityData, target: Unit, point: Vector3, has_point: bool, tick := false) -> void:
	var ctx := EffectContext.create(_unit, target if target != null else _unit,
			StringName("ability:%s" % ability.id), ability.display_name)
	ctx.ability = ability
	ctx.point = point
	ctx.has_point = has_point
	Combat.execute(ability.get_effects_for(_unit), ctx)
	if not tick:
		Combat.notify_ability_cast(_unit, ability.id, target)


func _pay_cost(ability: AbilityData) -> void:
	var resource := ability.get_cost_resource()
	var cost := get_cost(ability)
	var stats := _unit.get_stats()
	if resource != &"" and cost > 0.0 and stats != null:
		stats.spend_resource(resource, minf(cost, stats.get_resource(resource)))


func _start_cooldown(ability: AbilityData) -> void:
	var duration := ability.get_number_for(_unit, "abklingzeit")
	if duration <= 0.0:
		return
	var now := Network.host_time()
	var maximum := ability.get_charges()
	if maximum > 1:
		var entry: Array = _charges.get(String(ability.id), [maximum, 0.0, duration, maximum])
		entry[0] = maxi(0, int(entry[0]) - 1)
		if float(entry[1]) <= now:
			entry[1] = now + duration
		entry[2] = duration
		entry[3] = maximum
		_charges[String(ability.id)] = entry
	else:
		_cooldowns[String(ability.get_cooldown_key())] = [now, now + duration]
	_cd_dirty = true


func _recharge(now: float) -> void:
	for key: String in _charges.keys():
		var entry: Array = _charges[key]
		var changed := false
		while int(entry[0]) < int(entry[3]) and float(entry[1]) > 0.0 and now >= float(entry[1]):
			entry[0] = int(entry[0]) + 1
			entry[1] = float(entry[1]) + float(entry[2]) if int(entry[0]) < int(entry[3]) else 0.0
			changed = true
		if changed:
			_cd_dirty = true
			if int(entry[0]) >= int(entry[3]):
				_charges.erase(key)


func _publish_cooldowns() -> void:
	_cd_dirty = false
	var now := Network.host_time()
	var cds := {}
	for key: String in _cooldowns.keys():
		if float(_cooldowns[key][1]) > now:
			cds[key] = _cooldowns[key].duplicate()
		else:
			_cooldowns.erase(key)
	var locks := {}
	for key: String in _locks.keys():
		if float(_locks[key]) > now:
			locks[key] = _locks[key]
		else:
			_locks.erase(key)
	var charges := {}
	for key: String in _charges:
		charges[key] = (_charges[key] as Array).duplicate()
	cooldown_state = {"gcd": _gcd.duplicate(), "cd": cds, "ch": charges, "lock": locks,
			"next": String(_next_swing["ability"].id) if not _next_swing.is_empty() else ""}


func _send_result(peer: int, req_id: int, code: int, param: String) -> void:
	if peer == 0:
		return
	if peer == multiplayer.get_unique_id():
		_on_result(req_id, code, param)
	elif multiplayer.get_peers().has(peer):
		_rpc_result.rpc_id(peer, req_id, code, param)


func _send_error(peer: int, code: int, param := "") -> void:
	if peer == 0:
		return
	if peer == multiplayer.get_unique_id():
		_owner_fail(code, param, null)
	elif multiplayer.get_peers().has(peer):
		_rpc_error.rpc_id(peer, code, param)


func _on_states_changed(_states: int) -> void:
	if not Network.is_host() or _cast.is_empty():
		return
	var combat := _unit.get_combat()
	var ability: AbilityData = _cast["ability"]
	if not combat.can_act() or (ability.is_spell and combat.has_state(Combat.STATE_SILENCED)):
		_end_cast(Result.INTERRUPTED)


## Host: Hat sich eine fremde Spielfigur seit Beginn des Zaubers deutlich
## bewegt (gemeldete Position)?
func _moved_since_start() -> bool:
	if _cast.is_empty() or not _unit is PlayerCharacter or _unit.is_multiplayer_authority():
		return false
	var player := _unit as PlayerCharacter
	var origin: Vector3 = _cast["origin"]
	var offset := player.net_position - origin
	offset.y = 0.0
	return offset.length() > Data.konstante(&"zauber_bewegung_toleranz", 1.0)


# --- Automatischer Angriff (Host) --------------------------------------------

func _toggle_auto_attack(target: Unit) -> void:
	if _unit.auto_attacking:
		_unit.auto_attacking = false
	else:
		_start_auto_attack(target if target != null else _unit.current_target)


func _start_auto_attack(target: Unit) -> void:
	if target == null or not is_instance_valid(target) or target.is_dead() or not target.can_be_attacked_by(_unit):
		return
	_unit.current_target = target
	_unit.auto_attacking = true


func _process_auto_attack(now: float) -> void:
	if not _unit.auto_attacking:
		return
	var target := _unit.current_target
	if target == null or target.is_dead() or not target.can_be_attacked_by(_unit) \
			or not target.is_visible_to(_unit):
		_unit.auto_attacking = false
		_next_swing = {}
		_cd_dirty = true
		return
	if not _cast.is_empty() or _unit.is_dead():
		return
	var combat := _unit.get_combat()
	if combat != null and not combat.can_act():
		return
	var stats := _unit.get_stats()
	var melee_range := Data.konstante(&"nahkampf_reichweite", 5.0)
	var distance := _unit.distance_to_unit(target)
	var ranged := stats != null and stats.has_flag(StatBlock.FLAG_RANGED_WEAPON) and distance > melee_range
	var row := Combat.weapon_row(_unit, ranged)
	if row == null:
		return
	var reach := float(row.get_value("reichweite", melee_range)) if ranged else melee_range
	var offhand := not ranged and stats != null and stats.has_flag(StatBlock.FLAG_OFFHAND_WEAPON)
	var main_ready := now >= (_ranged_at if ranged else _main_at)
	var off_ready := offhand and now >= _off_at
	if not main_ready and not off_ready:
		return
	if distance > reach + 0.001:
		_auto_error(AbilityError.Code.OUT_OF_RANGE)
		return
	if not _unit.is_in_front(target):
		_auto_error(AbilityError.Code.NOT_FACING)
		return
	if ranged and not _unit.has_line_of_sight_to(target):
		_auto_error(AbilityError.Code.NO_LINE_OF_SIGHT)
		return
	if main_ready:
		var speed := maxf(0.1, float(row.get_value("tempo", 2.0))) / _haste_factor()
		if ranged:
			_ranged_at = now + speed
			_swing(target, row, 1.0, &"auto:fernkampf", "Automatischer Schuss")
		else:
			_main_at = now + speed
			if _next_swing.is_empty() or not _try_next_swing(target):
				_swing(target, row, 1.0, &"auto:haupthand", "Automatischer Angriff")
	# Nebenhand (Beidhändigkeit): eigener Takt, halber Schaden.
	if off_ready:
		var off_row := Data.platzhalterwaffe(&"nebenhand")
		if off_row != null:
			_off_at = now + maxf(0.1, float(off_row.get_value("tempo", 2.0))) / _haste_factor()
			_swing(target, off_row, Data.konstante(&"nebenhand_faktor", 0.5), &"auto:nebenhand",
					"Automatischer Angriff (Nebenhand)")


## Ein Schlag bzw. Schuss (#34: mit Trefferwürfel, Krit, Rüstung und Blocken).
## Mit zwei Waffen (Beidhändigkeit) verfehlen beide Hände häufiger
## (verfehlen_beidhaendig in spielkonstanten.csv).
func _swing(target: Unit, row: TableRow, factor: float, source: StringName, source_name: String) -> void:
	var amount := Combat.weapon_damage(_unit, row) * factor
	var ctx := EffectContext.create(_unit, target, source, source_name)
	var ranged := source == &"auto:fernkampf"
	var stats := _unit.get_stats()
	var flags := Combat.FLAG_DUAL_WIELD \
			if not ranged and stats != null and stats.has_flag(StatBlock.FLAG_OFFHAND_WEAPON) else 0
	Combat.roll_damage(_unit, target, amount, &"physisch",
			HitFormulas.AttackKind.RANGED if ranged else HitFormulas.AttackKind.MELEE, ctx, flags)


## Nächster Schlag: statt des normalen Schlags die Fähigkeit (Kosten jetzt).
func _try_next_swing(target: Unit) -> bool:
	var entry := _next_swing
	_next_swing = {}
	_cd_dirty = true
	var ability: AbilityData = entry["ability"]
	if not has_resource_for(ability):
		_send_error(int(entry["peer"]), AbilityError.Code.NO_RESOURCE, String(ability.get_cost_resource()))
		return false
	_pay_cost(ability)
	_start_cooldown(ability)
	_apply(ability, target, Vector3.ZERO, false)
	return true


func _auto_error(code: int) -> void:
	var peer := _unit.get_controlling_peer() if _unit.is_player_unit() else 0
	if peer == 0:
		return
	var now := Network.host_time()
	if float(_auto_errors.get(code, -INF)) + AUTO_ERROR_INTERVAL > now:
		return
	_auto_errors[code] = now
	_send_error(peer, code)


# --- Intern: Besitzer --------------------------------------------------------

func _send(ability: AbilityData, target: Unit, point: Vector3, has_point: bool, predict: bool) -> void:
	_req_seq += 1
	var req := _req_seq
	var host := Network.is_host()
	if predict and not host:
		_predict(req, ability, target)
	_pending[req] = ability
	requested.emit(ability)
	if host:
		var result := host_use(ability, target, point, has_point, req, multiplayer.get_unique_id())
		if int(result[0]) >= 0:
			_on_result(req, int(result[0]), str(result[1]))
		return
	var view := _local_view()
	var target_path := target.get_path() if target != null and is_instance_valid(target) and target.is_inside_tree() \
			else NodePath()
	var facing: Vector3 = view["facing"]
	var yaw := atan2(-facing.x, -facing.z)
	var ability_id := String(ability.id)
	var moving := bool(view["moving"])
	var pos: Vector3 = view["pos"]
	_send_delayed(func() -> void:
		_rpc_use.rpc_id(1, req, ability_id, target_path, point, has_point, pos, yaw, moving))


## Wünsche an den Host mit der künstlichen Verzögerung aus dem
## Entwickler-Panel (#30) zurückhalten (gleiche Verzögerung = gleiche
## Reihenfolge).
func _send_delayed(callback: Callable) -> void:
	var delay := Network.artificial_delay_ms
	if delay <= 0 or not is_inside_tree():
		callback.call()
		return
	get_tree().create_timer(delay / 1000.0).timeout.connect(func() -> void:
		if is_inside_tree() and multiplayer.has_multiplayer_peer():
			callback.call())


func _predict(req: int, ability: AbilityData, target: Unit) -> void:
	var now := Network.host_time()
	if not ability.ignores_gcd:
		_pred_gcd = [now, now + get_gcd_duration(), req]
	if _is_toggle_off(ability) or ability.on_next_swing:
		return
	var cast_type := get_cast_type(ability)
	if cast_type != AbilityData.CastType.CAST:
		var duration := ability.get_number_for(_unit, "abklingzeit")
		if duration > 0.0:
			if ability.get_charges() > 1:
				var key := String(ability.id)
				var used: Array = _pred_charges.get(key, [0, []])
				used[0] = int(used[0]) + 1
				(used[1] as Array).append(req)
				_pred_charges[key] = used
			else:
				_pred_cd[String(ability.get_cooldown_key())] = [now, now + duration, req]
	if cast_type != AbilityData.CastType.INSTANT:
		var channel := cast_type == AbilityData.CastType.CHANNELED
		var duration := get_channel_time(ability) if channel else get_cast_time(ability)
		_pred_cast = {"ability": ability, "start": now, "end": now + duration, "channel": channel,
				"interruptible": ability.interruptible, "school": ability.get_school(),
				"target_path": target.get_path() if target != null and target.is_inside_tree() else NodePath(),
				"req": req, "predicted": true}
		cast_changed.emit()
	if ability.starts_auto_attack and _unit is PlayerCharacter and target != null \
			and target.can_be_attacked_by(_unit):
		var targeting := (_unit as PlayerCharacter).get_targeting()
		if targeting != null and target == targeting.target:
			targeting.select(target, true)
	cooldowns_changed.emit()


func _on_result(req: int, code: int, param: String) -> void:
	var ability: AbilityData = _pending.get(req)
	_pending.erase(req)
	if code == AbilityError.Code.OK:
		return
	_drop_req(req)
	if not _pred_gcd.is_empty() and int(_pred_gcd[2]) == req:
		_pred_gcd = []
	for key: String in _pred_cd.keys():
		if int(_pred_cd[key][2]) == req:
			_pred_cd.erase(key)
	_release_charge(req)
	if not _pred_cast.is_empty() and int(_pred_cast["req"]) == req:
		var cast_ability: AbilityData = _pred_cast["ability"]
		_pred_cast = {}
		cast_changed.emit()
		cast_ended.emit(Result.FAILED, cast_ability.id)
	cooldowns_changed.emit()
	_owner_fail(code, param, ability)


func _drop_req(req: int) -> void:
	_dropped_reqs.append(req)
	if _dropped_reqs.size() > 8:
		_dropped_reqs.pop_front()


func _release_charge(req: int) -> void:
	for key: String in _pred_charges.keys():
		var used: Array = _pred_charges[key]
		if (used[1] as Array).has(req):
			(used[1] as Array).erase(req)
			used[0] = maxi(0, int(used[0]) - 1)
		if int(used[0]) <= 0:
			_pred_charges.erase(key)


func _owner_process() -> void:
	var now := Network.host_time()
	# Vorhersage übernimmt Verzögerungen des Hosts (gleiche Dauer ab eigenem Start).
	if not _pred_cast.is_empty():
		var host := _parse_cast(cast_state)
		if not host.is_empty() and int(host["req"]) == int(_pred_cast["req"]):
			var duration := float(host["end"]) - float(host["start"])
			_pred_cast["end"] = float(_pred_cast["start"]) + duration
		elif now > float(_pred_cast["end"]) + PREDICTION_TIMEOUT:
			_pred_cast = {}
			cast_changed.emit()
	if not _pred_gcd.is_empty() and now > float(_pred_gcd[1]):
		_pred_gcd = []
	for key: String in _pred_cd.keys():
		if now > float(_pred_cd[key][1]):
			_pred_cd.erase(key)
	# Vorhergesagte Ladungen gelten, bis der Host sie übernommen hat.
	for key: String in _pred_charges.keys():
		var used: Array = _pred_charges[key]
		var still: Array = (used[1] as Array).filter(func(r: int) -> bool: return _pending.has(r))
		used[1] = still
		used[0] = still.size()
		if still.is_empty():
			_pred_charges.erase(key)
	_process_client_queue()


func _process_client_queue() -> void:
	if _client_queue.is_empty():
		return
	var ability: AbilityData = _client_queue["ability"]
	if Network.host_time() > float(_client_queue["until"]):
		_client_queue = {}
		return
	if get_wait_time(ability) > 0.0:
		return
	var entry := _client_queue
	_client_queue = {}
	var target: Unit = entry["target"] if is_instance_valid(entry["target"]) else null
	request_use(ability, target, entry["point"], entry["has_point"])


func _on_cast_end_received() -> void:
	if cast_end.size() < 4:
		return
	var seq := int(cast_end[0])
	if seq == _last_end_seq:
		return
	_last_end_seq = seq
	var req := int(cast_end[1])
	var result := int(cast_end[2])
	var ability_id := StringName(str(cast_end[3]))
	if not _pred_cast.is_empty():
		if int(_pred_cast["req"]) != req:
			return
		_pred_cast = {}
		cast_changed.emit()
	elif is_owner() and req == _locally_ended_req:
		return
	cast_ended.emit(result, ability_id)


func _owner_fail(code: int, param: String, ability: AbilityData) -> void:
	failed.emit(code, param, ability)


func _on_moving_changed(moving: bool) -> void:
	if not moving or not is_owner():
		return
	_client_queue = {}
	var info := get_cast_info()
	if info.is_empty():
		return
	var ability: AbilityData = info["ability"]
	if ability.castable_while_moving:
		return
	request_cancel(AbilityError.Code.MOVING)


# --- Intern: Prüfungen -------------------------------------------------------

func _fail(code: int, param := "") -> Array:
	return [code, param, null]


func _is_toggle_off(ability: AbilityData) -> bool:
	return ability.toggle_aura != null and _unit.get_combat() != null \
			and _unit.get_combat().get_stacks(ability.toggle_aura.id, _unit) > 0


func _needs_unit_target(ability: AbilityData) -> bool:
	return ability.target_kind in [AbilityData.TargetKind.ENEMY, AbilityData.TargetKind.FRIENDLY,
			AbilityData.TargetKind.ANY]


## [Code, Zusatz, Ziel]: Ziel nach Art der Fähigkeit.
func _resolve_target(ability: AbilityData, target: Unit) -> Array:
	if target != null and (not is_instance_valid(target) or not target.is_inside_tree()):
		target = null
	match ability.target_kind:
		AbilityData.TargetKind.NONE, AbilityData.TargetKind.GROUND:
			return [AbilityError.Code.OK, "", _unit]
		AbilityData.TargetKind.FRIENDLY:
			if target == null or _unit.get_reaction_to(target) != Unit.Reaction.FRIENDLY:
				target = _unit
			if target.is_dead():
				return _fail(AbilityError.Code.TARGET_DEAD)
			return [AbilityError.Code.OK, "", target]
		AbilityData.TargetKind.ENEMY:
			if target == null:
				return _fail(AbilityError.Code.NO_TARGET)
			if target.is_dead():
				return _fail(AbilityError.Code.TARGET_DEAD)
			if not target.can_be_attacked_by(_unit) or not target.is_visible_to(_unit):
				return _fail(AbilityError.Code.INVALID_TARGET)
			return [AbilityError.Code.OK, "", target]
		AbilityData.TargetKind.ANY:
			if target == null:
				return _fail(AbilityError.Code.NO_TARGET)
			if target.is_dead():
				return _fail(AbilityError.Code.TARGET_DEAD)
			if not target.is_visible_to(_unit):
				return _fail(AbilityError.Code.INVALID_TARGET)
			return [AbilityError.Code.OK, "", target]
	return [AbilityError.Code.OK, "", _unit]


func _check_range(ability: AbilityData, target: Unit, point: Vector3, has_point: bool,
		view: Dictionary) -> int:
	var pos: Vector3 = view.get("pos", _unit.global_position)
	var tolerance := float(view.get("tolerance", 0.0))
	var reach := get_range(ability) + tolerance
	if ability.target_kind == AbilityData.TargetKind.GROUND:
		if not has_point:
			return AbilityError.Code.INVALID_POINT
		var flat := Vector2(point.x - pos.x, point.z - pos.z).length()
		if flat > reach + 0.001:
			return AbilityError.Code.OUT_OF_RANGE
		if ability.requires_line_of_sight and not _ray_clear(_eye(pos), point + Vector3.UP, []):
			return AbilityError.Code.NO_LINE_OF_SIGHT
		return AbilityError.Code.OK
	if target == null or target == _unit:
		return AbilityError.Code.OK
	if _distance_from(pos, target) > reach + 0.001:
		return AbilityError.Code.OUT_OF_RANGE
	if ability.requires_line_of_sight \
			and not _ray_clear(_eye(pos), target.get_eye_position(), [_unit.get_rid(), target.get_rid()]):
		return AbilityError.Code.NO_LINE_OF_SIGHT
	return AbilityError.Code.OK


func _has_weapon(requirement: AbilityData.WeaponRequirement) -> bool:
	var stats := _unit.get_stats()
	match requirement:
		AbilityData.WeaponRequirement.NONE:
			return true
		AbilityData.WeaponRequirement.MELEE:
			return stats != null and stats.has_flag(StatBlock.FLAG_MELEE_WEAPON)
		AbilityData.WeaponRequirement.SHIELD:
			return stats != null and stats.has_flag(StatBlock.FLAG_SHIELD)
		AbilityData.WeaponRequirement.OFFHAND:
			return stats != null and stats.has_flag(StatBlock.FLAG_OFFHAND_WEAPON)
		AbilityData.WeaponRequirement.RANGED:
			return stats != null and stats.has_flag(StatBlock.FLAG_RANGED_WEAPON)
	return true


## Entfernung Rand zu Rand von einer (gemeldeten) Position des Wirkers.
func _distance_from(pos: Vector3, other: Unit) -> float:
	var pb := other.global_position
	var horizontal := maxf(0.0, Vector2(pb.x - pos.x, pb.z - pos.z).length()
			- _unit.get_body_radius() - other.get_body_radius())
	var vertical := maxf(0.0, maxf(pos.y - (pb.y + other.get_body_height()),
			pb.y - (pos.y + _unit.get_body_height())))
	return Vector2(horizontal, vertical).length()


func _is_facing(view: Dictionary, other: Unit) -> bool:
	var facing: Vector3 = view.get("facing", _unit.get_facing())
	var to: Vector3 = other.global_position - (view.get("pos", _unit.global_position) as Vector3)
	to.y = 0.0
	if to.length_squared() < 0.0001:
		return true
	var angle := deg_to_rad(Data.konstante(&"blickwinkel_vorne", 180.0)) / 2.0
	return facing.angle_to(to.normalized()) <= angle + 0.001


func _is_behind(view: Dictionary, other: Unit) -> bool:
	var to: Vector3 = (view.get("pos", _unit.global_position) as Vector3) - other.global_position
	to.y = 0.0
	if to.length_squared() < 0.0001:
		return false
	var angle := deg_to_rad(Data.konstante(&"blickwinkel_hinten", 180.0)) / 2.0
	return (-other.get_facing()).angle_to(to.normalized()) <= angle + 0.001


func _eye(pos: Vector3) -> Vector3:
	return pos + Vector3.UP * _unit.get_body_height() * Unit.EYE_HEIGHT


func _ray_clear(from: Vector3, to: Vector3, exclude: Array[RID]) -> bool:
	if not _unit.is_inside_tree():
		return false
	var query := PhysicsRayQueryParameters3D.create(from, to, Unit.LINE_OF_SIGHT_MASK, exclude)
	return _unit.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Werte dieser Instanz: eigene Position, Blickrichtung, Bewegung (bei
## fremden Figuren auf dem Host nicht bekannt: false, der Besitzer meldet).
func _local_view() -> Dictionary:
	var moving := false
	if _unit is PlayerCharacter and _unit.is_multiplayer_authority():
		moving = (_unit as PlayerCharacter).is_moving
	return {"pos": _unit.global_position, "facing": _unit.get_facing(), "moving": moving}


## Host: Werte einer fremden Figur aus ihrem Wunsch, sofern plausibel
## (nahe der zuletzt gemeldeten Position); Reichweite mit Toleranz.
func _remote_view(pos: Vector3, yaw: float, moving: bool) -> Dictionary:
	var known := _unit.global_position
	if _unit is PlayerCharacter:
		known = (_unit as PlayerCharacter).net_position
	if pos.distance_to(known) > MAX_REPORTED_OFFSET:
		pos = known
	var facing := Vector3(-sin(yaw), 0.0, -cos(yaw))
	return {"pos": pos, "facing": facing, "moving": moving,
			"tolerance": Data.konstante(&"reichweite_toleranz", 1.0)}


## Host: Werte für Prüfungen am Ende einer Zauberzeit.
func _host_view() -> Dictionary:
	var view := _local_view()
	if _unit is PlayerCharacter and not _unit.is_multiplayer_authority():
		view["pos"] = (_unit as PlayerCharacter).net_position
		view["tolerance"] = Data.konstante(&"reichweite_toleranz", 1.0)
	return view


func _haste_factor() -> float:
	var stats := _unit.get_stats() if _unit != null else null
	var haste := stats.get_value(&"haste_pct") if stats != null else 0.0
	return maxf(0.1, 1.0 + haste / 100.0)


func _charge_entry(ability: AbilityData) -> Array:
	var maximum := ability.get_charges()
	var charges: Dictionary = _charges if Network.is_host() else cooldown_state.get("ch", {})
	var entry: Array = charges.get(String(ability.id), [])
	if entry.size() < 4:
		return [maximum, 0.0, ability.get_number_for(_unit, "abklingzeit"), maximum]
	return entry


func _parse_cast(state: Array) -> Dictionary:
	if state.size() < 8:
		return {}
	var ability := GameData.get_ability(StringName(str(state[0])))
	if ability == null:
		return {}
	return {"ability": ability, "start": float(state[1]), "end": float(state[2]),
			"channel": bool(state[3]), "interruptible": bool(state[4]), "school": StringName(str(state[5])),
			"target_path": state[6], "req": int(state[7]), "predicted": false}


# --- Platzhalter-Leuchten beim Zaubern ---------------------------------------

## Graubox: halb durchsichtige Hülle um die Einheit in der Farbe der Schule
## (CombatColors, Theme), solange sie zaubert. Auf jeder Instanz gleich.
func _update_glow() -> void:
	if _unit == null or not _unit.is_inside_tree():
		return
	var info := get_cast_info()
	if info.is_empty():
		if _glow != null:
			_glow.visible = false
		return
	if _glow == null:
		var mesh := CapsuleMesh.new()
		mesh.radius = _unit.get_body_radius() + 0.15
		mesh.height = _unit.get_body_height() + 0.3
		_glow_material = StandardMaterial3D.new()
		_glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glow_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh.material = _glow_material
		_glow = MeshInstance3D.new()
		_glow.name = "CastGlow"
		_glow.mesh = mesh
		_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_glow.position = Vector3.UP * _unit.get_body_height() / 2.0
		_unit.add_child(_glow)
	var school: StringName = info["school"]
	if school != _glow_school:
		_glow_school = school
		_glow_material.albedo_color = CombatColors.cast_glow_color(school)
	_glow.visible = _unit.is_visible_to(Unit.local_player(get_tree()))
