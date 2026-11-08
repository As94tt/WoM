class_name CharacterRules
extends Resource
## Regeln, nach denen der Host mitgebrachte Charaktere prüft (Ticket #30).
## Der Standardsatz liegt in res://data/characters/character_rules.tres.
## Die Stufengrenze ist vorläufig (GDD: Stufenobergrenze offen), kein Endwert.

## Niedrigste erlaubte Stufe.
@export var min_level: int = 1
## Höchste erlaubte Stufe (vorläufig).
@export var max_level: int = 60
## Längster erlaubter Name. Etwas länger als bei der Erstellung (12), weil
## Testcharaktere eine Zahl anhängen („Test123“).
@export var max_name_length: int = 16


## Prüft die beim Beitreten gesendeten Charakterdaten (CharacterData.to_dict()).
## Leerer String = in Ordnung, sonst ein verständlicher Grund.
func validate(data: Dictionary) -> String:
	var character_name = data.get("character_name")
	if not character_name is String:
		return "Der Charakter hat keinen Namen."
	var name_text: String = character_name
	if name_text.length() < CharacterNameValidator.MIN_LENGTH or name_text.length() > max_name_length:
		return "Der Name muss %d bis %d Zeichen lang sein." % [CharacterNameValidator.MIN_LENGTH, max_name_length]
	if not _is_letters_and_digits(name_text):
		return "Der Name darf nur Buchstaben von A bis Z und Ziffern enthalten."
	var race_id = data.get("race_id")
	if not (race_id is String or race_id is StringName) or GameData.get_race(StringName(race_id)) == null:
		return "Unbekanntes Volk."
	var class_id = data.get("class_id")
	if not (class_id is String or class_id is StringName) or GameData.get_class_data(StringName(class_id)) == null:
		return "Unbekannte Klasse."
	var gender = data.get("gender")
	if not gender is int or not CharacterData.Gender.values().has(gender):
		return "Unbekanntes Geschlecht."
	var level = data.get("level")
	if not level is int or level < min_level or level > max_level:
		return "Die Stufe muss zwischen %d und %d liegen." % [min_level, max_level]
	return ""


static func _is_letters_and_digits(text: String) -> bool:
	for i in text.length():
		var code := text.unicode_at(i)
		var digit := code >= 48 and code <= 57  # 0 bis 9
		if not digit and not CharacterNameValidator.is_plain_letters(text[i]):
			return false
	return true
