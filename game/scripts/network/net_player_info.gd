class_name NetPlayerInfo
extends RefCounted
## Ein Spieler der Sitzung, wie ihn der Autoload „Network“ führt (Ticket #30).
## Der Host legt die Einträge an und schickt die Liste an alle Mitspieler;
## Clients lesen sie nur. Für die Übertragung per RPC gibt es to_dict() und
## from_dict() (nur einfache Typen).

## Peer-ID (1 = Host). Gleichzeitig Knotenname der Figur unter „Players“.
var peer_id: int = 0
## Name des Charakters, wie ihn der Spieler mitgebracht hat.
var character_name: String = ""
## Name im Spiel. Gleich character_name, außer ein anderer Spieler hat denselben
## Namen; dann mit Zusatz, z. B. „Arthas (2)“.
var display_name: String = ""
var race_id: StringName = &""
var gender: int = CharacterData.Gender.MALE
var class_id: StringName = &""
var level: int = 1
## true, sobald der Spieler die Welt geladen hat und seine Figur existiert.
var in_world := false
## Round-Trip-Zeit zum Host in Millisekunden (vom Host gemessen, 0 beim Host).
var ping_ms: int = 0


## Eintrag aus einem (vom Host geprüften) Charakter.
static func from_character(id: int, c: CharacterData) -> NetPlayerInfo:
	var info := NetPlayerInfo.new()
	info.peer_id = id
	info.character_name = c.character_name
	info.display_name = c.character_name
	info.race_id = c.race_id
	info.gender = c.gender
	info.class_id = c.class_id
	info.level = c.level
	return info


func is_host() -> bool:
	return peer_id == 1


func get_class_data() -> ClassData:
	return GameData.get_class_data(class_id)


func get_race() -> RaceData:
	return GameData.get_race(race_id)


func to_dict() -> Dictionary:
	return {
		"peer_id": peer_id,
		"character_name": character_name,
		"display_name": display_name,
		"race_id": String(race_id),
		"gender": gender,
		"class_id": String(class_id),
		"level": level,
		"in_world": in_world,
		"ping_ms": ping_ms,
	}


static func from_dict(data: Dictionary) -> NetPlayerInfo:
	var info := NetPlayerInfo.new()
	info.peer_id = int(data.get("peer_id", 0))
	info.character_name = str(data.get("character_name", ""))
	info.display_name = str(data.get("display_name", info.character_name))
	info.race_id = StringName(str(data.get("race_id", "")))
	info.gender = int(data.get("gender", CharacterData.Gender.MALE))
	info.class_id = StringName(str(data.get("class_id", "")))
	info.level = int(data.get("level", 1))
	info.in_world = bool(data.get("in_world", false))
	info.ping_ms = int(data.get("ping_ms", 0))
	return info
