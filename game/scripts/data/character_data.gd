class_name CharacterData
extends Resource
## Ein gespeicherter Spielercharakter (Ticket #6). Liegt lokal unter
## user://characters/, eine Datei pro Charakter (siehe CharacterStore).
## Volk und Klasse sind nur als ID gespeichert; die Daten dazu liefert GameData.
## Seit #20 auch Spezialisierung, Talentränge, freigeschaltete Spezialisierungen
## und Bonuspunkte; sie gehen beim Beitreten mit to_dict() an den Host und
## werden gespeichert, sobald der Host eine Änderung bestätigt (PlayerTalents).

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

@export_group("Spezialisierung und Talente (#20)")
## Gewählte Spezialisierung (SpecializationData.id, leer = keine).
@export var specialization_id: StringName = &""
## Ränge der Talente im Baum der Spezialisierung: Talent-ID → Rang.
@export var talent_ranks: Dictionary = {}
## Freigeschaltete gesperrte Spezialisierungen (vorerst nur über das
## Entwickler-Panel).
@export var unlocked_specializations: PackedStringArray = []
## Zusätzliche Talentpunkte aus dem Entwickler-Panel.
@export var bonus_talent_points: int = 0
@export_group("")

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
		"talents": get_talent_dict(),
	}


## Spezialisierung und Talente (#20) im Format von PlayerTalents.talent_state:
## {"spec", "ranks", "unlocked", "bonus"} – nur einfache Typen. Wird beim
## Beitreten an den Host übertragen, der damit rechnet.
func get_talent_dict() -> Dictionary:
	return {
		"spec": String(specialization_id),
		"ranks": TalentRules.clean_ranks(talent_ranks),
		"unlocked": Array(unlocked_specializations),
		"bonus": maxi(0, bonus_talent_points),
	}


## Gegenstück zu get_talent_dict() (bestätigter Stand vom Host).
func set_talent_dict(data: Dictionary) -> void:
	specialization_id = StringName(str(data.get("spec", "")))
	talent_ranks = TalentRules.clean_ranks(data.get("ranks", {}))
	var unlocked := PackedStringArray()
	var list: Variant = data.get("unlocked", [])
	if list is Array or list is PackedStringArray:
		for entry: Variant in list:
			unlocked.append(str(entry))
	unlocked_specializations = unlocked
	bonus_talent_points = maxi(0, int(data.get("bonus", 0)))


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
	var talents: Variant = data.get("talents", {})
	if talents is Dictionary:
		c.set_talent_dict(talents)
	return c
