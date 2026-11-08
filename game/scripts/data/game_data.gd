class_name GameData
extends RefCounted
## Zentraler Zugriff auf Völker und Klassen (Ticket #6).
## Klassen sind .tres in res://data/classes/ (neue Klasse = neue .tres-Datei).
## Völker stehen seit #39 in der Tabelle voelker.csv und kommen aus dem
## Autoload „Data“; nach „Tabellen neu laden“ liefert get_races() den neuen Stand.

const CLASSES_DIR := "res://data/classes/"

static var _classes: Array[ClassData] = []
static var _loaded := false


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
