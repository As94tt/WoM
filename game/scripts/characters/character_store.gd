class_name CharacterStore
extends RefCounted
## Lokaler Speicher der Spielercharaktere (Ticket #6).
## Eine Datei pro Charakter unter user://characters/<name klein>.tres.
## Charaktere gehören dem Spieler und verlassen seinen PC nie als Datei;
## beim Beitreten (M1) wird nur CharacterData.to_dict() übertragen.

const DIR := "user://characters/"
const MAX_CHARACTERS := 10


## Alle lesbaren Charaktere, sortiert nach Name. Defekte oder fremde Dateien
## werden mit Warnung übersprungen.
static func list_all() -> Array[CharacterData]:
	var result: Array[CharacterData] = []
	if not DirAccess.dir_exists_absolute(DIR):
		return result
	for file in DirAccess.get_files_at(DIR):
		if not file.ends_with(".tres"):
			continue
		var path := DIR + file
		# Ohne Cache laden, damit Änderungen aus einem zweiten Spielfenster
		# beim erneuten Öffnen sichtbar werden.
		var res := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if not (res is CharacterData):
			push_warning("CharacterStore: %s ist kein lesbarer Charakter und wird übersprungen." % path)
			continue
		var c: CharacterData = res
		if c.character_name.strip_edges().is_empty():
			push_warning("CharacterStore: %s hat keinen Namen und wird übersprungen." % path)
			continue
		c.storage_path = path
		result.append(c)
	result.sort_custom(func(a: CharacterData, b: CharacterData) -> bool:
		return a.character_name.naturalnocasecmp_to(b.character_name) < 0)
	return result


static func count() -> int:
	return list_all().size()


## Dateipfad für einen Charakternamen.
static func path_for_name(character_name: String) -> String:
	return DIR + character_name.strip_edges().to_lower() + ".tres"


## true, wenn schon ein Charakter mit diesem Namen (ohne Groß-/Kleinschreibung)
## gespeichert ist.
static func name_exists(character_name: String) -> bool:
	return FileAccess.file_exists(path_for_name(character_name))


## Speichert den Charakter. Neue Charaktere bekommen ihren Pfad aus dem Namen.
static func save(c: CharacterData) -> Error:
	var file_name := c.character_name.strip_edges().to_lower()
	if file_name.is_empty() or not file_name.is_valid_filename():
		push_error("CharacterStore: Ungültiger Charaktername „%s“." % c.character_name)
		return ERR_INVALID_PARAMETER
	var err := DirAccess.make_dir_recursive_absolute(DIR)
	if err != OK:
		push_error("CharacterStore: Ordner %s konnte nicht angelegt werden (%s)." % [DIR, error_string(err)])
		return err
	var path := c.storage_path if not c.storage_path.is_empty() else path_for_name(c.character_name)
	err = ResourceSaver.save(c, path)
	if err != OK:
		push_error("CharacterStore: %s konnte nicht gespeichert werden (%s)." % [path, error_string(err)])
		return err
	c.storage_path = path
	return OK


## Löscht die Datei des Charakters.
static func delete(c: CharacterData) -> Error:
	var path := c.storage_path if not c.storage_path.is_empty() else path_for_name(c.character_name)
	if not FileAccess.file_exists(path):
		push_warning("CharacterStore: %s existiert nicht mehr." % path)
		return ERR_FILE_NOT_FOUND
	var err := DirAccess.remove_absolute(path)
	if err != OK:
		push_error("CharacterStore: %s konnte nicht gelöscht werden (%s)." % [path, error_string(err)])
	return err
