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
## - Die Angriffspuppe ergänzt #35.
##
## Netzwerk: Der Host erzeugt die Puppe (UnitSpawner der Welt), rechnet Leben,
## Anzeige und Rücksetzen. „ServerSync“ überträgt Kennung, Position, Rang
## und Anzeigewerte, „StatsSync“ wie bei Spielern Leben und Werte. Schaden und
## Heilung kommen über Combat.deal_damage/Combat.heal (#32, Entwickler-Panel
## „Einheiten“ und „Auren“), die am Ende apply_damage/apply_heal rufen. Den
## Kampfzustand verwaltet seit #32 UnitCombat (Kindknoten „Combat“): Die
## Puppe ist nach Schaden 5 s im Kampf; das Zurücksetzen der Anzeige bleibt
## bei puppe_ruecksetzen_nach. „StatsSync“ überträgt auch ihre Auren.

enum Kind { DAMAGE, HEALING }

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

var _row: TableRow = null
## Host: Ereignisse im Anzeigefenster als [Zeit in s, Betrag].
var _events: Array[Array] = []
## Host: Gesamtschaden bzw. Überheilung seit dem letzten Zurücksetzen.
var _total := 0.0
## Host: Zeitpunkt des letzten Schadens bzw. der letzten Heilung (s), −1 = keins.
var _last_event_time := -1.0
var _loss_elapsed := 0.0

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
	if get_kind() == Kind.HEALING:
		_lose_health(delta)
	if _last_event_time >= 0.0 and now - _last_event_time >= Data.konstante(&"puppe_ruecksetzen_nach", 10.0):
		_reset()
		return
	_update_meter(now)


## Sendet die Puppe auch an Peers, die inzwischen die Welt geladen haben.
func refresh_visibility() -> void:
	for sync in [_server_sync, _stats_sync, $CastSync]:
		sync.update_visibility()


func get_kind() -> Kind:
	return Kind.HEALING if _row != null and String(_row.get_value("art", "schaden")) == "heilung" \
			else Kind.DAMAGE


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


func get_stat_base_overrides() -> Dictionary:
	return {&"max_health": float(_row.get_value("leben", 1))} if _row != null else {}


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
	return "Schaden pro Sekunde: %s\nGesamt: %s" % [
			StatFormat.grouped(meter_rate), StatFormat.grouped(meter_total)]


## Host: Schaden. Bei 0 Leben füllt sich die Schadenspuppe sofort wieder auf.
func apply_damage(amount: float, source: Unit = null) -> float:
	var dealt := super.apply_damage(amount, source)
	if get_kind() == Kind.DAMAGE and amount > 0.0:
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
	# Schadenspuppen gehen bis 0 (und füllen sich dann auf), Heilpuppen nie.
	_stats.min_health = 0.0 if get_kind() == Kind.DAMAGE else CharacterStats.MIN_HEALTH
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
	if get_kind() == Kind.DAMAGE:
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
