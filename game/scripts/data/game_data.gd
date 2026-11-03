class_name GameData
extends RefCounted
## Zentraler Zugriff auf die Spieldaten aus res://data/ (Ticket #6).
## Lädt beim ersten Zugriff alle Völker und Klassen und hält sie im Speicher.
## Neue Völker oder Klassen entstehen durch eine neue .tres-Datei, ohne Code.

const RACES_DIR := "res://data/races/"
const CLASSES_DIR := "res://data/classes/"

static var _races: Array[RaceData] = []
static var _classes: Array[ClassData] = []
static var _loaded := false


## Alle Völker, sortiert nach order.
static func get_races() -> Array[RaceData]:
	_ensure_loaded()
	return _races


## Alle Klassen, sortiert nach order.
static func get_classes() -> Array[ClassData]:
	_ensure_loaded()
	return _classes


## Volk zur ID oder null.
static func get_race(race_id: StringName) -> RaceData:
	for race in get_races():
		if race.id == race_id:
			return race
	return null


## Klasse zur ID oder null.
static func get_class_data(class_id: StringName) -> ClassData:
	for class_data in get_classes():
		if class_data.id == class_id:
			return class_data
	return null


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	for res in _load_all(RACES_DIR):
		if res is RaceData:
			_races.append(res)
		else:
			push_warning("GameData: %s ist kein RaceData und wird übersprungen." % res.resource_path)
	for res in _load_all(CLASSES_DIR):
		if res is ClassData:
			_classes.append(res)
		else:
			push_warning("GameData: %s ist kein ClassData und wird übersprungen." % res.resource_path)
	_races.sort_custom(func(a: RaceData, b: RaceData) -> bool: return a.order < b.order)
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
