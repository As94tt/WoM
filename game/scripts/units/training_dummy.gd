class_name TrainingDummy
extends Unit
## Übungspuppe im Trainingsbereich (Ticket #31). Werte aus uebungspuppen.csv
## (dummy_id), aufgestellt vom Host an den Aufstellpunkten (UnitSpawnPoint).
##
## - Schadenspuppe (art „schaden“): greift nie an, stirbt nie – fällt das
##   Leben auf 0, füllt es sich sofort wieder auf. Zeigt über sich den Schaden
##   pro Sekunde (gemittelt über puppe_anzeige_fenster, höchstens seit dem
##   ersten Treffer) und den Gesamtschaden. Nach puppe_ruecksetzen_nach
##   Sekunden ohne Schaden setzt sie sich zurück (Anzeige 0, Leben voll).
## - Heilpuppe (art „heilung“): verliert alle verlust_intervall Sekunden
##   verlust_prozent ihres Lebens (nie unter 1). Zeigt Heilung pro Sekunde und
##   Überheilung; setzt die Anzeige nach derselben Zeit ohne Heilung zurück.
## - Angriffspuppe (art „angriff“, #35): steht still, dreht sich zum Ziel und
##   schlägt den Spieler mit der höchsten Bedrohung (Ziel nach
##   UnitCombat.get_threat_target, also mit 110/130 % und Spott), sobald er in
##   Nahkampfreichweite ist: alle angriff_takt Sekunden angriff_schaden
##   körperlich (Nahkampfwurf: Ausweichen, Parieren, Blocken und Rüstung des
##   Spielers wirken). Stirbt nie (füllt sich bei 0 auf wie die
##   Schadenspuppe) und zeigt über sich Schaden pro Sekunde und ihr Ziel.
## - Entwickler-Panel (#33): „Ziel zaubert …“ lässt die Puppe einen
##   Testzauber immer wieder wirken (Kindknoten „Caster“, wie alle Einheiten).
##
## Netzwerk: Der Host erzeugt die Puppe (UnitSpawner der Welt), rechnet Leben,
## Anzeige und Rücksetzen. „ServerSync“ überträgt Kennung, Position, Rang
## und Anzeigewerte, „StatsSync“ wie bei Spielern Leben und Werte. Schaden und
## Heilung kommen über Combat.deal_damage/Combat.heal (#32, Entwickler-Panel
## „Einheiten“ und „Auren“), die am Ende apply_damage/apply_heal rufen. Den
## Kampfzustand verwaltet seit #32 UnitCombat (Kindknoten „Combat“): Die
## Puppe ist nach Schaden 5 s im Kampf; das Zurücksetzen der Anzeige bleibt
## bei puppe_ruecksetzen_nach. „StatsSync“ überträgt auch ihre Auren.

enum Kind { DAMAGE, HEALING, ATTACK }

const KIND_IDS := {"schaden": Kind.DAMAGE, "heilung": Kind.HEALING, "angriff": Kind.ATTACK}

## Spalte in uebungspuppen.csv → Wert im Wertesystem (#34).
const DEFENSE_COLUMNS := {
	"ruestung": &"armor",
	"zauberschutz": &"spell_ward",
	"ausweichen": &"dodge",
	"parieren": &"parry",
	"blocken": &"block",
	"blockwert": &"block_value",
}

## Zeile in uebungspuppen.csv. Beim Erzeugen gesetzt (Host) und übertragen.
@export var dummy_id: StringName = &"":
	set(value):
		dummy_id = value
		if is_node_ready():
			_apply_data()

## Rang aus dem Entwickler-Panel (−1 = aus den Daten). Übertragen.
var rank_override: int = -1:
	set(value):
		rank_override = value
		unit_changed.emit()

## Anzeige, vom Host gerechnet und übertragen: Schaden bzw. Heilung pro
## Sekunde und Gesamtschaden bzw. Überheilung (gerundet, damit nur echte
## Änderungen gesendet werden).
var meter_rate: int = 0:
	set(value):
		meter_rate = value
		unit_changed.emit()
var meter_total: int = 0:
	set(value):
		meter_total = value
		unit_changed.emit()

## Host: Entwickler-Panel (#33) – die Puppe wirkt diese Fähigkeit immer
## wieder (leer = nicht), damit Unterbrechungen und Zauberleisten testbar sind.
var dev_cast_ability: StringName = &""
var _dev_cast_pause := 0.0

var _row: TableRow = null
## Host: Ereignisse im Anzeigefenster als [Zeit in s, Betrag].
var _events: Array[Array] = []
## Host: Gesamtschaden bzw. Überheilung seit dem letzten Zurücksetzen.
var _total := 0.0
## Host: Zeitpunkt des letzten Schadens bzw. der letzten Heilung (s), −1 = keins.
var _last_event_time := -1.0
var _loss_elapsed := 0.0
## Host (Angriffspuppe): nächster Schlag frühestens (s).
var _next_attack := 0.0

@onready var _stats: CharacterStats = $Stats
@onready var _server_sync: MultiplayerSynchronizer = $ServerSync
@onready var _stats_sync: MultiplayerSynchronizer = $StatsSync


func _enter_tree() -> void:
	# Die Synchronizer gehören immer dem Host.
	$ServerSync.set_multiplayer_authority(1)
	$StatsSync.set_multiplayer_authority(1)
	$CastSync.set_multiplayer_authority(1)


func _ready() -> void:
	for sync in [_server_sync, _stats_sync]:
		sync.add_visibility_filter(Network.is_peer_in_world)
	_stats.regeneration_enabled = false
	_apply_data()


func _process(delta: float) -> void:
	if not multiplayer.is_server() or _row == null:
		return
	var now := _now()
	_process_dev_cast(delta)
	if get_kind() == Kind.HEALING:
		_lose_health(delta)
	elif get_kind() == Kind.ATTACK:
		_process_attack(now)
	if _last_event_time >= 0.0 and now - _last_event_time >= Data.konstante(&"puppe_ruecksetzen_nach", 10.0):
		_reset()
		return
	_update_meter(now)


## Host: Testzauber der Puppe wiederholen (eine Sekunde Pause dazwischen,
## nach Unterbrechung so lange, wie die Schule gesperrt ist).
func _process_dev_cast(delta: float) -> void:
	var caster := get_caster_node()
	if dev_cast_ability == &"" or caster == null or caster.is_casting():
		_dev_cast_pause = 1.0
		return
	_dev_cast_pause -= delta
	if _dev_cast_pause > 0.0:
		return
	_dev_cast_pause = 1.0
	var ability := GameData.get_ability(dev_cast_ability)
	if ability != null:
		caster.host_use(ability, null)


## Sendet die Puppe auch an Peers, die inzwischen die Welt geladen haben.
func refresh_visibility() -> void:
	for sync in [_server_sync, _stats_sync, $CastSync]:
		sync.update_visibility()


func get_kind() -> Kind:
	if _row == null:
		return Kind.DAMAGE
	return KIND_IDS.get(String(_row.get_value("art", "schaden")), Kind.DAMAGE)


## Host (Angriffspuppe): zum Ziel nach Bedrohung drehen und im Takt schlagen.
func _process_attack(now: float) -> void:
	var combat := get_combat()
	var target := combat.get_threat_target() if combat != null else null
	if target == null or target.is_dead() or is_dead():
		return
	var to := target.global_position - global_position
	to.y = 0.0
	if to.length_squared() > 0.0001:
		rotation.y = atan2(-to.x, -to.z)
	if now < _next_attack or distance_to_unit(target) > Data.konstante(&"nahkampf_reichweite", 5.0):
		return
	_next_attack = now + maxf(0.1, float(_row.get_value("angriff_takt", 2.0)))
	var ctx := EffectContext.create(self, target, &"puppe:angriff", "Angriff")
	Combat.roll_damage(self, target, float(_row.get_value("angriff_schaden", 0.0)), &"physisch",
			HitFormulas.AttackKind.MELEE, ctx)


# --- Einheit -----------------------------------------------------------------

func get_unit_name() -> String:
	return String(_row.get_value("name", dummy_id)) if _row != null else String(dummy_id)


func get_stats() -> CharacterStats:
	return _stats


func get_base_reaction() -> Unit.Reaction:
	return Unit.reaction_from_id(String(_row.get_value("gesinnung", "feindlich"))) if _row != null \
			else Unit.Reaction.HOSTILE


func get_rank() -> Unit.Rank:
	if rank_override >= 0:
		return rank_override as Unit.Rank
	return Unit.rank_from_id(String(_row.get_value("rang", "normal"))) if _row != null else Unit.Rank.NORMAL


func get_base_level() -> int:
	return int(_row.get_value("stufe", 1)) if _row != null else 1


## Feste Grundwerte aus uebungspuppen.csv: Leben und seit #34 die
## Abwehrwerte (Rüstung, Zauberschutz, Ausweichen, Parieren, Blocken,
## Blockwert); leere Zellen lassen das Wertesystem rechnen.
func get_stat_base_overrides() -> Dictionary:
	if _row == null:
		return {}
	var result := {&"max_health": float(_row.get_value("leben", 1))}
	for column: String in DEFENSE_COLUMNS:
		if not _row.is_blank(column):
			result[DEFENSE_COLUMNS[column]] = float(_row.get_value(column, 0.0))
	return result


## Immunitäten aus uebungspuppen.csv (#32), z. B. die Bosspuppe.
func get_base_immunities() -> PackedStringArray:
	var result := PackedStringArray()
	if _row != null:
		for id: Variant in _row.get_value("immunitaeten", []):
			result.append(str(id))
	return result


## Puppen stehen fest auf ihrem Pfosten (Rückstoß, Heranziehen wirken nicht).
func can_be_moved() -> bool:
	return false


## Über der Puppe, zweizeilig: „Schaden pro Sekunde: 120“ und
## „Gesamt: 3.400“ bzw. für die Heilpuppe Heilung pro Sekunde und Überheilung.
func get_overhead_text() -> String:
	if get_kind() == Kind.HEALING:
		return "Heilung pro Sekunde: %s\nÜberheilung: %s" % [
				StatFormat.grouped(meter_rate), StatFormat.grouped(meter_total)]
	var text := "Schaden pro Sekunde: %s\nGesamt: %s" % [
			StatFormat.grouped(meter_rate), StatFormat.grouped(meter_total)]
	if get_kind() == Kind.ATTACK:
		var combat := get_combat()
		var target := combat.get_threat_target() if combat != null else null
		text += "\nGreift an: %s" % (target.get_unit_name() if target != null else "–")
	return text


## Host: Schaden. Bei 0 Leben füllt sich die Schadens- bzw. Angriffspuppe
## sofort wieder auf (sie stirbt nie).
func apply_damage(amount: float, source: Unit = null) -> float:
	var dealt := super.apply_damage(amount, source)
	if get_kind() != Kind.HEALING and amount > 0.0:
		_record(amount, amount)
		if _stats.health <= 0.0:
			_stats.refill()
	return dealt


## Host: Heilung. Die Heilpuppe zählt Heilung pro Sekunde und Überheilung.
func apply_heal(amount: float, source: Unit = null) -> float:
	var overheal := super.apply_heal(amount, source)
	if get_kind() == Kind.HEALING and amount > 0.0:
		_record(amount, overheal)
	return overheal


# --- Intern ------------------------------------------------------------------

func _apply_data() -> void:
	_row = Data.uebungspuppe(dummy_id)
	if _row == null and dummy_id != &"":
		push_warning("TrainingDummy: Übungspuppe „%s“ fehlt in uebungspuppen.csv." % dummy_id)
	# Schadens- und Angriffspuppen gehen bis 0 (und füllen sich dann auf),
	# Heilpuppen nie unter MIN_HEALTH.
	_stats.min_health = CharacterStats.MIN_HEALTH if get_kind() == Kind.HEALING else 0.0
	# Stufe und Grundwerte (Leben) aus den Daten übernehmen.
	_stats.refresh_from_unit()
	_stats.reapply()
	if multiplayer.is_server():
		_stats.refill()
	unit_changed.emit()


func _record(amount: float, total_part: float) -> void:
	var now := _now()
	_events.append([now, amount])
	_total += total_part
	_last_event_time = now
	_update_meter(now)


func _update_meter(now: float) -> void:
	var window := Data.konstante(&"puppe_anzeige_fenster", 60.0)
	while not _events.is_empty() and now - float(_events[0][0]) > window:
		_events.pop_front()
	var rate := 0.0
	if not _events.is_empty():
		var sum := 0.0
		for event in _events:
			sum += float(event[1])
		# Bis das Fenster voll ist, zählt die Zeit seit dem ersten Treffer
		# (mindestens 1 s, damit der erste Treffer nicht riesig wirkt).
		var span := clampf(now - float(_events[0][0]), 1.0, window)
		rate = sum / span
	meter_rate = roundi(rate)
	meter_total = roundi(_total)


func _reset() -> void:
	_events.clear()
	_total = 0.0
	_last_event_time = -1.0
	meter_rate = 0
	meter_total = 0
	if get_kind() != Kind.HEALING:
		_stats.refill()


func _lose_health(delta: float) -> void:
	var interval := maxf(0.1, float(_row.get_value("verlust_intervall", 1.0)))
	var percent := float(_row.get_value("verlust_prozent", 0.0))
	if percent <= 0.0:
		return
	_loss_elapsed += delta
	while _loss_elapsed >= interval:
		_loss_elapsed -= interval
		_stats.set_health(maxf(CharacterStats.MIN_HEALTH, _stats.health - _stats.max_health * percent / 100.0))


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
