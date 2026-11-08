class_name CharacterData
extends Resource
## Ein gespeicherter Spielercharakter (Ticket #6). Liegt lokal unter
## user://characters/, eine Datei pro Charakter (siehe CharacterStore).
## Volk und Klasse sind nur als ID gespeichert; die Daten dazu liefert GameData.

enum Gender { MALE, FEMALE }

@export var character_name: String
@export var race_id: StringName
@export var gender: Gender = Gender.MALE
@export var class_id: StringName
@export var level: int = 1
## Unix-Zeit, zu der zuletzt mit dem Charakter gespielt wurde (0 = nie).
@export var last_played: int = 0
## Belegung der Aktionsleisten (#21, ActionBarLayout.to_save): je Leiste
## 12 Einträge wie „ability:feuerball“ oder „“ (leer). Leer (keine Leisten)
## = noch nie belegt; dann bekommt der Charakter beim Betreten der Welt die
## Standardbelegung (neue und bestehende Charaktere). Bleibt lokal und wird
## nicht an den Host übertragen.
@export var action_bars: Array[PackedStringArray] = []

## Datei, aus der der Charakter geladen bzw. in die er gespeichert wurde.
## Wird von CharacterStore gesetzt und nicht mitgespeichert.
var storage_path: String = ""
## Nur für diese Sitzung (Testcharakter der Startparameter, #30); wird nie
## gespeichert.
var is_temporary := false


## Volk-Daten oder null, wenn die ID unbekannt ist.
func get_race() -> RaceData:
	return GameData.get_race(race_id)


## Klassen-Daten oder null, wenn die ID unbekannt ist.
func get_class_data() -> ClassData:
	return GameData.get_class_data(class_id)


## Testcharakter für die Startparameter --host/--join ohne --character (#30):
## Mensch, männlich, Magier, Stufe 1, Name „Test“ plus Zufallszahl. Wird nicht
## gespeichert.
static func make_test_character() -> CharacterData:
	var c := CharacterData.new()
	c.character_name = "Test%d" % randi_range(100, 999)
	c.race_id = &"human"
	c.gender = Gender.MALE
	c.class_id = &"mage"
	c.level = 1
	c.is_temporary = true
	return c


## Für die Übertragung beim Beitreten (#30): nur einfache Typen,
## damit es per RPC verschickt werden kann.
func to_dict() -> Dictionary:
	return {
		"character_name": character_name,
		"race_id": String(race_id),
		"gender": int(gender),
		"class_id": String(class_id),
		"level": level,
		"last_played": last_played,
	}


## Gegenstück zu to_dict(). Fehlende Felder bekommen Standardwerte; Volk und
## Klasse prüft der Aufrufer (in M1 der Host) gegen GameData.
static func from_dict(data: Dictionary) -> CharacterData:
	var c := CharacterData.new()
	c.character_name = str(data.get("character_name", ""))
	c.race_id = StringName(str(data.get("race_id", "")))
	c.gender = clampi(int(data.get("gender", Gender.MALE)), Gender.MALE, Gender.FEMALE) as Gender
	c.class_id = StringName(str(data.get("class_id", "")))
	c.level = maxi(1, int(data.get("level", 1)))
	c.last_played = maxi(0, int(data.get("last_played", 0)))
	return c
