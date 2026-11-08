class_name CharacterStats
extends Node
## Werte und Ressourcen einer Spielfigur (Ticket #19). Kindknoten „Stats“ der
## Spielfigur (player.tscn); funktioniert ohne Interface. Die Rechnung macht
## StatBlock, dieser Knoten verwaltet Eingaben, Ressourcen und Netzwerk.
##
## Netzwerk: Der Host ist die Autorität über die Werte aller Charaktere.
## - Eingaben (Stufe, „Im Kampf“, „Nahkampfwaffe/Schild getragen“,
##   Modifikatoren) stehen in stat_state. Nur der Host ändert sie; „StatsSync“
##   (MultiplayerSynchronizer, Authority Host) überträgt sie an alle. Jede
##   Instanz rechnet daraus mit denselben Daten dieselben Werte (die
##   Prüfsumme der Tabellen ist beim Beitreten gleich, Neu laden ist mit
##   Mitspielern gesperrt).
## - Leben und Ressourcen (aktuell und maximal) rechnet nur der Host
##   (Regeneration, Schaden, Verbrauch); StatsSync überträgt sie an alle
##   (Vorbereitung für Einheitenrahmen #31).
## - Wünsche eines Clients (Entwickler-Panel) gehen per RPC an den Host
##   (request_dev_action), wie der Teleport aus #30.
##
## Schnittstelle für spätere Systeme (nur auf dem Host aufrufen):
##   add_modifier(StatModifier) / remove_source(&"aura:xyz")   – #29, #32
##   set_flag(StatBlock.FLAG_SHIELD, true)                      – #29
##   set_in_combat(true)                                        – Kampf (M2)
##   take_damage(x), register_damage_dealt(x)                   – Kampf (M2)
##   spend_resource(&"mana", x), gain_resource(&"chi", x)       – Fähigkeiten
## Lesen geht überall: get_value(&"attack_power"), get_resource(&"energy"),
## block (StatBlock) für Grundwert, Bonus und Modifikatoren.

## Ein Wert hat sich geändert (Modifikator, Stufe, Zustand); alles ist neu
## berechnet.
signal stats_changed
## Leben oder eine Ressource (aktuell oder maximal) hat sich geändert.
signal resources_changed
signal combat_changed(in_combat: bool)
## Die Stufe, mit der gerechnet wird, hat sich geändert (Charakter oder
## „Stufe ändern“ im Entwickler-Panel; ab #27 auch Stufenaufstieg). Auf allen
## Instanzen ausgelöst, sobald der neue Stand da ist; nicht beim ersten
## Stand nach dem Erzeugen (previous wäre dort unbekannt). Ausgewertet z. B.
## von PlayerAbilities (#21: neu erlernte Fähigkeiten).
signal level_changed(level: int, previous: int)
## Chi hat 100 % erreicht: Zustand „Chi voll“ (vorerst ohne Wirkung; was er
## bewirkt, legt das Fähigkeits-Ticket des Mönchs fest). Danach sinkt Chi
## auf 0. Auf allen Instanzen ausgelöst.
signal chi_full_triggered

const RULES: StatRules = preload("res://data/stats/stat_rules.tres")
const DEV_TOOLS: StatDevTools = preload("res://data/stats/dev_tools.tres")
## Ressourcen in fester Reihenfolge; das Maximum ist der Wert max_<id>.
const RESOURCE_IDS: Array[StringName] = [&"mana", &"rage", &"energy", &"chi"]
## Quelle der Testmodifikatoren aus dem Entwickler-Panel.
const DEV_SOURCE_PREFIX := "dev:test_"
## Leben sinkt durch „Schaden nehmen“ nicht unter diesen Wert (Tod kommt in M3).
const MIN_HEALTH := 1.0

## Eingaben, vom Host gesetzt und von StatsSync übertragen:
## {"level": int, "combat": bool, "melee": bool, "shield": bool,
##  "mods": [StatModifier.to_array(), …]}. Nie direkt ändern, sondern über
## die Funktionen unten (Host).
var stat_state: Dictionary = {}:
	set(value):
		stat_state = value
		if is_node_ready():
			_apply_state()

## Leben und Ressourcen, vom Host gerechnet und übertragen.
var health := 0.0
var max_health := 0.0
var mana := 0.0
var max_mana := 0.0
var rage := 0.0
var max_rage := 0.0
var energy := 0.0
var max_energy := 0.0
var chi := 0.0
var max_chi := 0.0
## true, solange Chi nach „Chi voll“ absinkt; dabei entsteht kein neues Chi.
var chi_draining := false:
	set(value):
		var started := value and not chi_draining
		chi_draining = value
		if started:
			chi_full_triggered.emit()

## Die Rechnung (überall gleich).
var block := StatBlock.new()

## Host: Stufe aus dem Entwickler-Panel (0 = Stufe des Charakters). Wird
## nicht gespeichert.
var _level_override := 0
## Host: Leben und Ressourcen wurden einmal aufgefüllt.
var _filled := false
var _was_in_combat := false
## Zuletzt gemeldete Stufe (0 = noch kein Stand, für level_changed).
var _last_level := 0
## Zuletzt gemeldeter Stand von Leben und Ressourcen (für resources_changed).
var _last_resources := PackedFloat32Array()

@onready var _player: PlayerCharacter = get_parent() as PlayerCharacter


func _ready() -> void:
	block.changed.connect(_on_block_changed)
	# Tabellen neu geladen (F6, nur ohne Mitspieler): mit den neuen Zahlen rechnen.
	Data.reloaded.connect(func(ok: bool, _lines: PackedStringArray) -> void:
		if ok:
			block.recalculate())
	if Network.is_host() and stat_state.is_empty():
		# Der Setter rechnet erst nach _ready, deshalb hier selbst.
		stat_state = _make_state(_player_level(), false, false, false, [])
	_apply_state()


func _process(delta: float) -> void:
	if Network.is_host() and _filled:
		_regenerate(delta)
	_emit_resources_if_changed()


# --- Lesen (überall) ---------------------------------------------------------

func get_value(stat: StringName) -> float:
	return block.get_value(stat)


## Stufe, mit der gerechnet wird (Charakter oder Entwickler-Panel).
func get_level() -> int:
	return block.level


func is_in_combat() -> bool:
	return bool(stat_state.get("combat", false))


func has_flag(flag: StringName) -> bool:
	return block.has_flag(flag)


## Ressourcen der Klasse in Anzeigereihenfolge (z. B. [&"energy", &"chi"]).
func get_resource_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	var class_data := GameData.get_class_data(block.class_id)
	if class_data != null:
		result.assign(class_data.resources)
	return result


func get_resource(resource_id: StringName) -> float:
	return float(get(String(resource_id))) if RESOURCE_IDS.has(resource_id) else 0.0


func get_resource_max(resource_id: StringName) -> float:
	return float(get("max_" + String(resource_id))) if RESOURCE_IDS.has(resource_id) else 0.0


# --- Ändern (nur Host) -------------------------------------------------------

func add_modifier(modifier: StatModifier) -> void:
	if not _require_host("add_modifier") or modifier == null:
		return
	var mods: Array = stat_state.get("mods", []).duplicate()
	mods.append(modifier.to_array())
	_set_state_value("mods", mods)


## Entfernt alle Modifikatoren der Quelle (z. B. &"item:schwert_rostig").
func remove_source(source: StringName) -> void:
	if not _require_host("remove_source"):
		return
	var mods: Array = stat_state.get("mods", []).filter(
			func(data: Array) -> bool: return StringName(str(data[0])) != source)
	_set_state_value("mods", mods)


func set_in_combat(on: bool) -> void:
	if _require_host("set_in_combat"):
		_set_state_value("combat", on)


## Zustände „Nahkampfwaffe getragen“ (StatBlock.FLAG_MELEE_WEAPON) und
## „Schild getragen“ (StatBlock.FLAG_SHIELD); später gesetzt von #29.
func set_flag(flag: StringName, on: bool) -> void:
	if not _require_host("set_flag"):
		return
	match flag:
		StatBlock.FLAG_MELEE_WEAPON:
			_set_state_value("melee", on)
		StatBlock.FLAG_SHIELD:
			_set_state_value("shield", on)
		_:
			push_warning("CharacterStats.set_flag: unbekannter Zustand %s." % flag)


## Stufe nur für diese Sitzung (Entwickler-Panel); 0 = Stufe des Charakters.
func set_level_override(level: int) -> void:
	if not _require_host("set_level_override"):
		return
	_level_override = maxi(0, level)
	_set_state_value("level", _player_level())


## Von der Spielfigur gerufen, wenn sich Klasse, Volk oder Stufe des
## Charakters ändern.
func refresh_from_player() -> void:
	if _player == null:
		return
	block.set_identity(_player.class_id, _player.race_id)
	if Network.is_host() and not stat_state.is_empty() \
			and int(stat_state.get("level", 0)) != _player_level():
		_set_state_value("level", _player_level())


## Schaden nehmen: Leben sinkt (nicht unter MIN_HEALTH, Tod folgt in M3),
## der Krieger bekommt Wut: Faktor × Schaden / maximales Leben.
func take_damage(amount: float) -> void:
	if not _require_host("take_damage") or amount <= 0.0:
		return
	health = maxf(MIN_HEALTH, health - amount)
	if max_rage > 0.0 and max_health > 0.0:
		rage = minf(max_rage, rage + Data.konstante(&"wut_pro_schaden_genommen") * amount / max_health)


## Schaden ausgeteilt: der Krieger bekommt Wut (Faktor × Schaden).
func register_damage_dealt(amount: float) -> void:
	if not _require_host("register_damage_dealt") or amount <= 0.0:
		return
	if max_rage > 0.0:
		rage = minf(max_rage, rage + Data.konstante(&"wut_pro_schaden_ausgeteilt") * amount)


## Verbraucht amount einer Ressource. false, wenn nicht genug da ist (dann
## wird nichts abgezogen).
func spend_resource(resource_id: StringName, amount: float) -> bool:
	if not _require_host("spend_resource") or not RESOURCE_IDS.has(resource_id):
		return false
	var current := get_resource(resource_id)
	if get_resource_max(resource_id) <= 0.0 or current < amount:
		return false
	set(String(resource_id), current - amount)
	return true


## Fügt amount einer Ressource hinzu (bis zum Maximum). Chi entsteht nicht,
## solange es nach „Chi voll“ absinkt; erreicht es das Maximum, wird der
## Zustand „Chi voll“ ausgelöst.
func gain_resource(resource_id: StringName, amount: float) -> void:
	if not _require_host("gain_resource") or not RESOURCE_IDS.has(resource_id) or amount <= 0.0:
		return
	var maximum := get_resource_max(resource_id)
	if maximum <= 0.0:
		return
	if resource_id == &"chi":
		if chi_draining:
			return
		chi = minf(maximum, chi + amount)
		if chi >= maximum:
			chi_draining = true
		return
	set(String(resource_id), minf(maximum, get_resource(resource_id) + amount))


# --- Entwickler-Panel --------------------------------------------------------

## Aktion aus dem Entwickler-Panel. Auf dem Host sofort, auf einem Client als
## Wunsch an den Host (nur für die eigene Figur).
func request_dev_action(action: String, value: Variant = null) -> void:
	if Network.is_host():
		_do_dev_action(action, value)
	else:
		_rpc_dev_action.rpc_id(1, action, value)


## Quelle des Testmodifikators Nummer index.
static func dev_source(index: int) -> StringName:
	return StringName(DEV_SOURCE_PREFIX + str(index))


## Text eines Testmodifikators, z. B. „+50 Stärke“.
static func dev_modifier_label(index: int) -> String:
	var data := DEV_TOOLS.test_modifiers[index]
	var definition := RULES.get_stat(data.stat)
	var stat_name := definition.display_name if definition != null else String(data.stat)
	return StatFormat.modifier(stat_name, definition, data.kind, data.value)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_dev_action(action: String, value: Variant) -> void:
	if not Network.is_host() or not OS.is_debug_build():
		return
	if _player == null or multiplayer.get_remote_sender_id() != _player.peer_id:
		return
	_do_dev_action(action, value)


func _do_dev_action(action: String, value: Variant) -> void:
	match action:
		"modifier":
			# value = [Nummer, an/aus]
			if not value is Array or value.size() < 2:
				return
			var index := int(value[0])
			if index < 0 or index >= DEV_TOOLS.test_modifiers.size():
				return
			remove_source(dev_source(index))
			if bool(value[1]):
				add_modifier(DEV_TOOLS.test_modifiers[index].to_modifier(
						dev_source(index), "Entwickler-Panel"))
		"level":
			set_level_override(clampi(int(value), 1, Data.hoechste_stufe()))
		"combat":
			set_in_combat(bool(value))
		"melee":
			set_flag(StatBlock.FLAG_MELEE_WEAPON, bool(value))
		"shield":
			set_flag(StatBlock.FLAG_SHIELD, bool(value))
		"take_damage":
			take_damage(max_health * DEV_TOOLS.damage_taken_percent / 100.0)
		"deal_damage":
			register_damage_dealt(DEV_TOOLS.damage_dealt)
		"spend":
			for resource_id in [&"mana", &"energy"]:
				spend_resource(resource_id, DEV_TOOLS.resource_spent)
		"build_chi":
			gain_resource(&"chi", DEV_TOOLS.chi_built)
		"refill":
			_fill_resources()
		_:
			push_warning("CharacterStats: unbekannte Entwickler-Aktion %s." % action)


# --- Intern ------------------------------------------------------------------

func _player_level() -> int:
	if _level_override > 0:
		return _level_override
	return _player.level if _player != null else 1


func _make_state(level: int, combat: bool, melee: bool, shield: bool, mods: Array) -> Dictionary:
	return {"level": level, "combat": combat, "melee": melee, "shield": shield, "mods": mods}


## Host: einen Eingabewert ändern. Es entsteht ein neues Dictionary, damit
## StatsSync die Änderung erkennt.
func _set_state_value(key: String, value: Variant) -> void:
	if stat_state.get(key) == value:
		return
	var state := stat_state.duplicate(true)
	state[key] = value
	stat_state = state


func _apply_state() -> void:
	if _player == null:
		return
	var mods: Array[StatModifier] = []
	for data: Variant in stat_state.get("mods", []):
		if data is Array:
			var m := StatModifier.from_array(data)
			if m != null:
				mods.append(m)
	var flags := {
		StatBlock.FLAG_MELEE_WEAPON: bool(stat_state.get("melee", false)),
		StatBlock.FLAG_SHIELD: bool(stat_state.get("shield", false)),
	}
	block.set_state(_player.class_id, _player.race_id, int(stat_state.get("level", 1)), flags, mods)
	if is_in_combat() != _was_in_combat:
		_was_in_combat = is_in_combat()
		combat_changed.emit(_was_in_combat)
	_check_level_changed()


## level_changed melden, wenn sich die Stufe eines echten Stands geändert hat.
## Ein leerer Stand (Client vor dem ersten StatsSync) zählt nicht.
func _check_level_changed() -> void:
	if stat_state.is_empty():
		return
	var level := int(stat_state.get("level", 1))
	if _last_level == 0:
		_last_level = level
		return
	if level != _last_level:
		var previous := _last_level
		_last_level = level
		level_changed.emit(level, previous)


func _on_block_changed() -> void:
	if Network.is_host():
		# Steigt das Maximum von Leben oder Mana (z. B. durch Ausdauer), steigt
		# der aktuelle Wert um denselben Betrag; sinkt es, wird nur begrenzt.
		var new_max_health := block.get_value(&"max_health")
		var new_max_mana := block.get_value(&"max_mana")
		if _filled:
			health += maxf(0.0, new_max_health - max_health)
			mana += maxf(0.0, new_max_mana - max_mana)
		max_health = new_max_health
		for resource_id in RESOURCE_IDS:
			set("max_" + String(resource_id), block.get_value(StatRules.max_stat_of(resource_id)))
		if not _filled:
			_fill_resources()
			_filled = true
		_clamp_resources()
	stats_changed.emit()


## Host: Leben, Mana und Energie voll, Wut und Chi leer.
func _fill_resources() -> void:
	health = max_health
	mana = max_mana
	energy = max_energy
	rage = 0.0
	chi = 0.0
	chi_draining = false


func _clamp_resources() -> void:
	health = clampf(health, 0.0, max_health)
	for resource_id in RESOURCE_IDS:
		var key := String(resource_id)
		set(key, clampf(float(get(key)), 0.0, float(get("max_" + key))))


## Host: Regeneration und Verfall je Bild. Alle Raten aus spielkonstanten.csv
## bzw. aus den Werten (Manaregeneration, Energieregeneration).
func _regenerate(delta: float) -> void:
	var combat := is_in_combat()
	if health < max_health:
		var percent := Data.konstante(&"leben_regen_im_kampf" if combat else &"leben_regen_ausser_kampf")
		health = minf(max_health, health + max_health * percent / 100.0 * delta)
	if max_mana > 0.0 and mana < max_mana:
		var factor := 1.0 if combat else Data.konstante(&"mana_regen_faktor_ausser_kampf", 1.0)
		mana = minf(max_mana, mana + block.get_value(&"mana_regen") * factor * delta)
	if max_rage > 0.0 and rage > 0.0 and not combat:
		rage = maxf(0.0, rage - Data.konstante(&"wut_verfall_pro_s") * delta)
	if max_energy > 0.0 and energy < max_energy:
		energy = minf(max_energy, energy + block.get_value(&"energy_regen") * delta)
	if chi_draining:
		chi = maxf(0.0, chi - Data.konstante(&"chi_verfall_pro_s") * delta)
		if chi <= 0.0:
			chi_draining = false


func _emit_resources_if_changed() -> void:
	var now := PackedFloat32Array([health, max_health, mana, max_mana, rage, max_rage,
			energy, max_energy, chi, max_chi])
	if now != _last_resources:
		_last_resources = now
		resources_changed.emit()


func _require_host(what: String) -> bool:
	if Network.is_host():
		return true
	push_warning("CharacterStats.%s: nur der Host ändert Werte." % what)
	return false
