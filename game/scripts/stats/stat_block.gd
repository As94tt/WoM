class_name StatBlock
extends RefCounted
## Die Werte eines Charakters (Ticket #19), ohne Interface und ohne Netzwerk:
## Eingaben (Klasse, Volk, Stufe, Zustände wie „Schild getragen“) plus
## Modifikatoren ergeben alle Attribute, Wertungen, Schutz- und Kampfwerte.
## Aufbau und Formeln stehen in res://data/stats/stat_rules.tres, die Zahlen
## in den Tabellen (Autoload „Data“).
##
## Jede Änderung (Modifikator, Stufe, Zustand) rechnet alle Werte neu und
## meldet changed. Für den Tooltip wird zusätzlich der Grundwert ohne
## Modifikatoren berechnet: Bonus = Wert − Grundwert (auch bei abgeleiteten
## Werten, z. B. Kampfkraft durch Stärke-Bonus).
##
## Benutzt von CharacterStats (Einheiten, Host-Autorität). Ausrüstung (#29)
## und Auren (#32) fügen Modifikatoren mit eigener Quelle hinzu und
## entfernen sie über remove_source().
##
## Einheiten ohne Klasse (Übungspuppen #31, später Gegner #36) setzen feste
## Grundwerte (base_overrides, z. B. {&"max_health": 100000}); sie ersetzen
## die Formel, Modifikatoren und Obergrenzen gelten weiterhin.

## Ein Eingabewert oder Modifikator hat sich geändert; alle Werte sind neu
## berechnet.
signal changed

const RULES: StatRules = preload("res://data/stats/stat_rules.tres")
## Zustände für requires_flag.
const FLAG_MELEE_WEAPON := &"melee_weapon"
const FLAG_SHIELD := &"shield"
## Zweite Nahkampfwaffe in der Nebenhand (Beidhändigkeit, #33) und
## Fernkampfwaffe (#33). Bis Ausrüstung kommt (#29), schaltet sie das
## Entwickler-Panel; der automatische Angriff liest sie.
const FLAG_OFFHAND_WEAPON := &"offhand_weapon"
const FLAG_RANGED_WEAPON := &"ranged_weapon"
## Wert, mit dem scales_with_haste rechnet.
const HASTE_STAT := &"haste_pct"

var class_id: StringName = &""
var race_id: StringName = &""
var level: int = 1

## Zustände (FLAG_*), z. B. Nahkampfwaffe oder Schild getragen. Setzt später
## die Ausrüstung (#29), bis dahin das Entwickler-Panel.
var _flags: Dictionary[StringName, bool] = {}
var _modifiers: Array[StatModifier] = []
## Feste Grundwerte statt Formel (Wert-ID → Zahl), siehe oben.
var _base_overrides: Dictionary[StringName, float] = {}
## Endwerte (mit Modifikatoren, mit Obergrenze).
var _values: Dictionary[StringName, float] = {}
## Grundwerte (ohne jeden Modifikator, mit Obergrenze).
var _base_values: Dictionary[StringName, float] = {}
## Wird gerade mehreres auf einmal geändert (set_state)?
var _batch := false


# --- Eingaben ----------------------------------------------------------------

## Setzt alle Eingaben auf einmal und rechnet einmal neu.
func set_state(p_class_id: StringName, p_race_id: StringName, p_level: int,
		flags: Dictionary, modifiers: Array[StatModifier], base_overrides: Dictionary = {}) -> void:
	_batch = true
	_base_overrides.clear()
	for stat: StringName in base_overrides:
		_base_overrides[stat] = float(base_overrides[stat])
	class_id = p_class_id
	race_id = p_race_id
	level = maxi(1, p_level)
	_flags.clear()
	for flag: StringName in flags:
		_flags[flag] = bool(flags[flag])
	_modifiers = modifiers.duplicate()
	_batch = false
	recalculate()


func set_identity(p_class_id: StringName, p_race_id: StringName) -> void:
	if class_id == p_class_id and race_id == p_race_id:
		return
	class_id = p_class_id
	race_id = p_race_id
	recalculate()


func set_level(p_level: int) -> void:
	p_level = maxi(1, p_level)
	if level == p_level:
		return
	level = p_level
	recalculate()


func set_flag(flag: StringName, on: bool) -> void:
	if has_flag(flag) == on:
		return
	_flags[flag] = on
	recalculate()


func has_flag(flag: StringName) -> bool:
	return _flags.get(flag, false)


func get_flags() -> Dictionary[StringName, bool]:
	return _flags.duplicate()


# --- Modifikatoren -----------------------------------------------------------

func add_modifier(modifier: StatModifier) -> void:
	if modifier == null:
		return
	_modifiers.append(modifier)
	recalculate()


## Entfernt alle Modifikatoren dieser Quelle. Gibt die Anzahl zurück.
func remove_source(source: StringName) -> int:
	var before := _modifiers.size()
	_modifiers = _modifiers.filter(func(m: StatModifier) -> bool: return m.source != source)
	var removed := before - _modifiers.size()
	if removed > 0:
		recalculate()
	return removed


func has_source(source: StringName) -> bool:
	return _modifiers.any(func(m: StatModifier) -> bool: return m.source == source)


## Alle Modifikatoren oder nur die auf einen Wert.
func get_modifiers(stat: StringName = &"") -> Array[StatModifier]:
	if stat == &"":
		return _modifiers.duplicate()
	var result: Array[StatModifier] = []
	for m in _modifiers:
		if m.stat == stat:
			result.append(m)
	return result


# --- Werte -------------------------------------------------------------------

## Endwert (mit Modifikatoren und Obergrenze). Unbekannt oder für die Klasse
## nicht relevant: 0.
func get_value(stat: StringName) -> float:
	return _values.get(stat, 0.0)


## Grundwert ohne jeden Modifikator.
func get_base(stat: StringName) -> float:
	return _base_values.get(stat, 0.0)


## Bonus (positiv) bzw. Malus (negativ) durch Modifikatoren.
func get_bonus(stat: StringName) -> float:
	return get_value(stat) - get_base(stat)


## true, wenn der Wert für Klasse und Zustände gilt (sonst ausgeblendet und 0).
func is_relevant(stat: StringName) -> bool:
	var definition := RULES.get_stat(stat)
	return definition != null and _is_relevant(definition, GameData.get_class_data(class_id))


## true, wenn die Obergrenze den Wert begrenzt.
func is_capped(stat: StringName) -> bool:
	var definition := RULES.get_stat(stat)
	if definition == null or definition.cap_key == "":
		return false
	return get_value(stat) >= Data.konstante(StringName(definition.cap_key), INF) - 0.0001


## Obergrenze des Werts oder INF.
func get_cap(stat: StringName) -> float:
	var definition := RULES.get_stat(stat)
	if definition == null or definition.cap_key == "":
		return INF
	return Data.konstante(StringName(definition.cap_key), INF)


## Rechnet alle Werte neu und meldet changed.
func recalculate() -> void:
	if _batch:
		return
	_base_values = _compute(false)
	_values = _compute(true)
	changed.emit()


# --- Formeln für den Kampf (M2) ----------------------------------------------

## Chance zu verfehlen in Prozent (kein Trefferwert): Grundwert plus fester
## Anteil je Stufe, die das Ziel höher ist, begrenzt auf Minimum und Maximum
## (spielkonstanten.csv). Die Formel steht seit #34 in HitFormulas.miss_chance.
static func miss_chance(attacker_level: int, target_level: int) -> float:
	return HitFormulas.miss_chance(attacker_level, target_level, Data.konstante(&"verfehlen_grund"),
			Data.konstante(&"verfehlen_pro_stufe"), Data.konstante(&"verfehlen_min"),
			Data.konstante(&"verfehlen_max", 100.0))


## Prozent aus einer Wertung auf einer Stufe (Spalte in umrechnung.csv).
static func rating_to_percent(conversion_column: String, rating: float, at_level: int) -> float:
	var row := Data.umrechnung(at_level)
	var per_percent := float(row.get_value(conversion_column, 0.0)) if row != null else 0.0
	return rating / per_percent if per_percent > 0.0 else 0.0


# --- Intern ------------------------------------------------------------------

func _compute(with_modifiers: bool) -> Dictionary[StringName, float]:
	var result: Dictionary[StringName, float] = {}
	var class_data := GameData.get_class_data(class_id)
	var class_values := Data.klassenwerte(class_id, level)
	var race_row := Data.row("voelker", race_id)
	var conversion := Data.umrechnung(level)
	for definition in RULES.stats:
		if not _base_overrides.has(definition.id) and not _is_relevant(definition, class_data):
			result[definition.id] = 0.0
			continue
		var value: float = _base_overrides[definition.id] if _base_overrides.has(definition.id) \
				else _formula(definition, result, class_data, class_values, race_row, conversion)
		if definition.scales_with_haste:
			value *= 1.0 + result.get(HASTE_STAT, 0.0) / 100.0
		if with_modifiers:
			value = _apply_modifiers(definition.id, value)
		if definition.cap_key != "":
			value = minf(value, Data.konstante(StringName(definition.cap_key), INF))
		result[definition.id] = maxf(value, 0.0)
	return result


func _formula(definition: StatDefinition, computed: Dictionary[StringName, float],
		class_data: ClassData, class_values: Dictionary, race_row: TableRow,
		conversion: TableRow) -> float:
	var source := definition.source
	if source == StatDefinition.PRIMARY_SOURCE:
		source = class_data.primary_attribute if class_data != null else &""
	var source_value: float = computed.get(source, 0.0) if source != &"" else 0.0
	match definition.formula:
		StatDefinition.Formula.INPUT:
			var value := 0.0
			if definition.level_column != "":
				value += float(class_values.get(definition.level_column, 0))
			if definition.race_column != "" and race_row != null:
				value += float(race_row.get_value(definition.race_column, 0))
			return value
		StatDefinition.Formula.LINEAR:
			var value := 0.0
			if definition.level_column != "":
				value += float(class_values.get(definition.level_column, 0))
			if definition.base_key != "":
				value += Data.konstante(StringName(definition.base_key))
			var factor := Data.konstante(StringName(definition.factor_key), 1.0) \
					if definition.factor_key != "" else 1.0
			return value + factor * source_value
		StatDefinition.Formula.RATING:
			var per_percent := float(conversion.get_value(definition.conversion_column, 0.0)) \
					if conversion != null else 0.0
			var base := Data.konstante(StringName(definition.base_key)) if definition.base_key != "" else 0.0
			return base + (source_value / per_percent if per_percent > 0.0 else 0.0)
		StatDefinition.Formula.DIMINISHING:
			var k := float(conversion.get_value(definition.conversion_column, 0.0)) \
					if conversion != null else 0.0
			if source_value <= 0.0 or source_value + k <= 0.0:
				return 0.0
			return 100.0 * source_value / (source_value + k)
	return 0.0


func _apply_modifiers(stat: StringName, value: float) -> float:
	var flat := 0.0
	var percent := 0.0
	for m in _modifiers:
		if m.stat != stat:
			continue
		if m.kind == StatModifier.Kind.PERCENT:
			percent += m.value
		else:
			flat += m.value
	return (value + flat) * (1.0 + percent / 100.0)


func _is_relevant(definition: StatDefinition, class_data: ClassData) -> bool:
	if definition.requires_primary:
		if class_data == null or class_data.primary_attribute != definition.id:
			return false
	if definition.requires_power != &"":
		if class_data == null or class_data.power_stat != definition.requires_power:
			return false
	if definition.requires_resource != &"":
		if class_data == null or not class_data.resources.has(definition.requires_resource):
			return false
	if definition.requires_flag != &"" and not has_flag(definition.requires_flag):
		return false
	return true
