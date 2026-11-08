class_name GameData
extends RefCounted
## Zentraler Zugriff auf Völker und Klassen (Ticket #6).
## Klassen sind .tres in res://data/classes/ (neue Klasse = neue .tres-Datei).
## Völker stehen seit #39 in der Tabelle voelker.csv und kommen aus dem
## Autoload „Data“; nach „Tabellen neu laden“ liefert get_races() den neuen Stand.
## Fähigkeiten (#21) sind .tres in res://data/abilities/ (get_ability), der
## Zauberbuch-Reiter „Allgemein“ liegt in res://data/spellbook/general.tres.

const CLASSES_DIR := "res://data/classes/"
const ABILITIES_DIR := "res://data/abilities/"
const GENERAL_TAB_PATH := "res://data/spellbook/general.tres"

static var _classes: Array[ClassData] = []
static var _loaded := false
static var _abilities: Dictionary[StringName, AbilityData] = {}
static var _abilities_loaded := false


## Alle Völker, sortiert nach order (aus voelker.csv).
static func get_races() -> Array[RaceData]:
	return Data.voelker()


## Alle Klassen, sortiert nach order.
static func get_classes() -> Array[ClassData]:
	_ensure_loaded()
	return _classes


## Volk zur ID oder null.
static func get_race(race_id: StringName) -> RaceData:
	return Data.volk(race_id)


## Klasse zur ID oder null.
static func get_class_data(class_id: StringName) -> ClassData:
	for class_data in get_classes():
		if class_data.id == class_id:
			return class_data
	return null


## Fähigkeit zur ID oder null.
static func get_ability(ability_id: StringName) -> AbilityData:
	_ensure_abilities_loaded()
	return _abilities.get(ability_id)


## Alle Fähigkeiten (unsortiert).
static func get_abilities() -> Array[AbilityData]:
	_ensure_abilities_loaded()
	var result: Array[AbilityData] = []
	result.assign(_abilities.values())
	return result


## Reiter „Allgemein“ des Zauberbuchs (Fähigkeiten für alle Klassen).
static func get_general_tab() -> SpellbookTabData:
	return load(GENERAL_TAB_PATH) as SpellbookTabData


static func _ensure_abilities_loaded() -> void:
	if _abilities_loaded:
		return
	_abilities_loaded = true
	for res in _load_all(ABILITIES_DIR):
		var ability := res as AbilityData
		if ability == null or ability.id == &"":
			push_warning("GameData: %s ist keine Fähigkeit mit ID und wird übersprungen." % res.resource_path)
			continue
		_abilities[ability.id] = ability
		_check_ability_table(ability)


## Klasse und Stufe stehen in der .tres und in faehigkeitswerte.csv; weichen
## sie ab, gilt die .tres (Warnung für die Datenpflege).
static func _check_ability_table(ability: AbilityData) -> void:
	var row := Data.faehigkeitswerte(ability.id)
	if row == null:
		return  # Meldet schon die Datenprüfung (#39).
	if String(row.get_value("klasse", "")) != String(ability.class_id) \
			or int(row.get_value("stufe", 1)) != ability.required_level:
		push_warning("GameData: Klasse/Stufe von %s weichen in faehigkeitswerte.csv von der .tres ab; es gilt die .tres." % ability.id)


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	for res in _load_all(CLASSES_DIR):
		if res is ClassData:
			_classes.append(res)
		else:
			push_warning("GameData: %s ist kein ClassData und wird übersprungen." % res.resource_path)
	_classes.sort_custom(func(a: ClassData, b: ClassData) -> bool: return a.order < b.order)


## Lädt alle .tres eines Ordners. ResourceLoader.list_directory funktioniert
## auch im exportierten Spiel (dort liegen die Dateien umbenannt im Paket).
static func _load_all(dir: String) -> Array[Resource]:
	var result: Array[Resource] = []
	var files := ResourceLoader.list_directory(dir)
	files.sort()
	for file in files:
		if not file.ends_with(".tres"):
			continue
		var res := load(dir + file)
		if res == null:
			push_warning("GameData: %s konnte nicht geladen werden." % (dir + file))
			continue
		result.append(res)
	return result
