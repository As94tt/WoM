class_name CharacterNameValidator
extends RefCounted
## Namensregeln für Charaktere (Ticket #8). Reine Logik ohne UI.
## Ein Name ist genau ein Wort aus 2 bis 12 Buchstaben A bis Z (keine Umlaute,
## Ziffern, Leer- oder Sonderzeichen). Er wird normalisiert: erster Buchstabe
## groß, Rest klein. Doppelt ist ein Name, wenn ein eigener Charakter nach der
## Normalisierung denselben Namen hat.

const MIN_LENGTH := 2
const MAX_LENGTH := 12

const MSG_TOO_SHORT := "Der Name braucht mindestens 2 Buchstaben."
const MSG_TOO_LONG := "Der Name darf höchstens 12 Buchstaben haben."
const MSG_INVALID := "Nur Buchstaben von A bis Z erlaubt, keine Leerzeichen, Zahlen, Umlaute oder Sonderzeichen."
const MSG_DUPLICATE := "Du hast bereits einen Charakter mit diesem Namen."


## Erster Buchstabe groß, Rest klein (z. B. „mAXi“ -> „Maxi“).
static func normalize(character_name: String) -> String:
	if character_name.is_empty():
		return ""
	return character_name.substr(0, 1).to_upper() + character_name.substr(1).to_lower()


## true, wenn der Text nur aus den Buchstaben A bis Z bzw. a bis z besteht.
static func is_plain_letters(text: String) -> bool:
	for i in text.length():
		var code := text.unicode_at(i)
		var upper := code >= 65 and code <= 90  # A bis Z
		var lower := code >= 97 and code <= 122  # a bis z
		if not (upper or lower):
			return false
	return true


## Prüft einen Namen. Leerer String = gültig, sonst eine verständliche Meldung.
## existing_names sind die Namen der eigenen Charaktere (beliebige Schreibweise).
static func validate(character_name: String, existing_names: Array[String] = []) -> String:
	if not is_plain_letters(character_name):
		return MSG_INVALID
	if character_name.length() < MIN_LENGTH:
		return MSG_TOO_SHORT
	if character_name.length() > MAX_LENGTH:
		return MSG_TOO_LONG
	var normalized := normalize(character_name)
	for existing in existing_names:
		if normalize(existing) == normalized:
			return MSG_DUPLICATE
	return ""
