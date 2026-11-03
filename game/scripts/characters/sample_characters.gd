class_name SampleCharacters
extends RefCounted
## Entwicklerhilfe (Ticket #6): legt Beispielcharaktere an, solange es die
## Charaktererstellung (#8) noch nicht gibt. Volk und Klasse kommen reihum aus
## GameData, damit kein Volk und keine Klasse im Code steht.

## Namen der Beispielcharaktere (nur Buchstaben). Mehr als MAX_CHARACTERS,
## damit wiederholtes Drücken die Liste bis zur Grenze füllen kann.
const NAMES: Array[String] = [
	"Durgin", "Brakka", "Zuljara", "Elandra", "Mirelle", "Thoran",
	"Velyra", "Gromm", "Isolde", "Kaelen", "Nyxa", "Orrin",
]
## Versatz in der Völkerliste, damit die ersten drei Beispiele klein,
## mittel und groß sind (Zwerg, Ork, Troll in der GDD-Reihenfolge).
const RACE_OFFSET := 3


## Legt bis zu count noch nicht vorhandene Beispielcharaktere an, ohne
## MAX_CHARACTERS zu überschreiten. Bestehende Charaktere bleiben unverändert.
## Gibt die Zahl der angelegten Charaktere zurück.
static func add_samples(count: int = 3) -> int:
	var races := GameData.get_races()
	var classes := GameData.get_classes()
	if races.is_empty() or classes.is_empty():
		push_warning("SampleCharacters: Keine Völker oder Klassen in res://data/ gefunden.")
		return 0
	var free_slots := CharacterStore.MAX_CHARACTERS - CharacterStore.count()
	var added := 0
	for i in NAMES.size():
		if added >= mini(count, free_slots):
			break
		if CharacterStore.name_exists(NAMES[i]):
			continue
		var c := CharacterData.new()
		c.character_name = NAMES[i]
		c.race_id = races[(i + RACE_OFFSET) % races.size()].id
		c.class_id = classes[i % classes.size()].id
		c.gender = CharacterData.Gender.MALE if i % 2 == 0 else CharacterData.Gender.FEMALE
		c.level = 1 + (i * 7) % 20
		if CharacterStore.save(c) == OK:
			added += 1
	return added
