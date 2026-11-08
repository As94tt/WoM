extends Node
## Autoload „Data“ (Ticket #39): die zentrale Stelle für alle Datentabellen.
## Lädt beim Spielstart alle Tabellen aus res://data/tables/ nach ihren
## Schemas (res://data/schemas/), prüft sie und stellt die Einträge per ID
## bereit. Kein anderes System liest CSV-Dateien selbst.
##
## Zugriff, z. B.:
##   Data.gegner("wolf_jung")             – Zeile (TableRow) oder null
##   Data.konstante("gcd")                – Zahl aus spielkonstanten.csv
##   Data.faehigkeitswert("feuerball", "werte.radius")
##   Data.voelker() / Data.volk(&"human") – Völker als RaceData
##
## Startparameter (ohne Spielstart, z. B. für Agenten und automatische Prüfungen):
##   --daten-pruefen   lädt und prüft alle Tabellen, gibt die Fehler aus und
##                     beendet das Programm (Rückgabewert 1 bei Fehlern)
##   --daten-doku      schreibt die Spaltenübersicht in docs/DATENTABELLEN.md
## Beispiel: godot --headless --path game -- --daten-pruefen
##
## Neu laden (nur Entwicklungsmodus): Taste F6 (Aktion „reload_tables“) oder
## Button im Entwickler-Panel. Bei Fehlern bleiben die alten Daten aktiv.
##
## Multiplayer: Die Prüfsumme (get_checksum) vergleicht der Host beim
## Beitreten (Network.get_data_hash). Neu laden ist gesperrt, solange
## Mitspieler verbunden sind, damit alle denselben Stand behalten.

## Nach jedem Versuch, die Tabellen neu zu laden. lines enthält die Meldung
## (und bei Fehlern die Fehlerliste) für Log oder Fehleranzeige.
signal reloaded(ok: bool, lines: PackedStringArray)

const SCHEMA_DIR := "res://data/schemas/"
const TABLE_DIR := "res://data/tables/"
## Dokumentation, relativ zum Projektordner game/.
const DOC_PATH := "../docs/DATENTABELLEN.md"
const RELOAD_ACTION := &"reload_tables"
const ARG_CHECK := "--daten-pruefen"
const ARG_DOC := "--daten-doku"

## true, wenn das Programm nur für --daten-pruefen / --daten-doku läuft.
## Das Hauptmenü startet dann nichts (kein Schnellstart, keine Fehleranzeige).
var command_line_mode := false

## Aktiver Stand der Daten.
var _data: DataSet = null
## true, sobald einmal ein fehlerfreier Stand geladen wurde.
var _valid := false
## Fehler des letzten Ladeversuchs (leer = in Ordnung).
var _last_errors: Array[DataError] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_loaded()
	var args := PackedStringArray()
	args.append_array(OS.get_cmdline_args())
	args.append_array(OS.get_cmdline_user_args())
	if args.has(ARG_CHECK) or args.has(ARG_DOC):
		command_line_mode = true
		_run_command_line(args.has(ARG_CHECK), args.has(ARG_DOC))


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build() or command_line_mode:
		return
	if event.is_action_pressed(RELOAD_ACTION) and not event.is_echo():
		get_viewport().set_input_as_handled()
		reload_tables()


# --- Zustand -----------------------------------------------------------------

## true, wenn ein fehlerfreier Stand aktiv ist. Ist er beim Start fehlerhaft,
## zeigt das Hauptmenü die Fehlerliste statt das Spiel zu starten.
func is_valid() -> bool:
	_ensure_loaded()
	return _valid


## Fehler des letzten Ladeversuchs (leer = in Ordnung).
func get_errors() -> Array[DataError]:
	_ensure_loaded()
	return _last_errors


## Prüfsumme der aktiven Daten (SHA-256 als Hex-Text).
func get_checksum() -> String:
	_ensure_loaded()
	return _data.checksum


## Leer = Neu laden ist möglich, sonst der Grund.
func get_reload_block_reason() -> String:
	if Network.has_other_players():
		return "Tabellen neu laden geht nur, solange keine Mitspieler verbunden sind."
	return ""


## Lädt alle Tabellen neu. Bei Fehlern bleiben die alten Daten aktiv (außer
## es gab noch nie einen fehlerfreien Stand). Gibt true bei Erfolg zurück.
func reload_tables() -> bool:
	_ensure_loaded()
	var reason := get_reload_block_reason()
	if reason != "":
		reloaded.emit(false, PackedStringArray([reason]))
		return false
	var fresh := DataSet.load_all(SCHEMA_DIR, TABLE_DIR)
	_last_errors = fresh.errors
	var lines: PackedStringArray = []
	if fresh.is_valid():
		_data = fresh
		_valid = true
		lines.append("Tabellen neu geladen (Prüfsumme %s)." % short_checksum())
		print("Daten: " + lines[0])
	else:
		if not _valid:
			_data = fresh
		lines.append("Tabellen enthalten %d Fehler; %s" % [fresh.errors.size(),
				"die alten Daten bleiben aktiv." if _valid else "es gibt noch keinen gültigen Stand."])
		for e in fresh.errors:
			lines.append(e.to_text())
		_print_errors(fresh.errors)
	reloaded.emit(fresh.is_valid(), lines)
	return fresh.is_valid()


## Die ersten Zeichen der Prüfsumme, z. B. für Anzeigen.
func short_checksum() -> String:
	return get_checksum().substr(0, 8)


# --- Zugriff -----------------------------------------------------------------

## Alle Zeilen einer Tabelle (Name ohne .csv).
func rows(table: String) -> Array:
	_ensure_loaded()
	return _data.get_rows(table)


## Zeile zum Schlüssel oder null; bei mehreren Schlüsselspalten ein Array.
func row(table: String, key: Variant) -> TableRow:
	_ensure_loaded()
	return _data.get_row(table, key)


## Alle Zeilen einer Tabelle, deren Spalte column den Wert value hat.
func rows_where(table: String, column: String, value: Variant) -> Array[TableRow]:
	_ensure_loaded()
	return _data.get_rows_where(table, column, value)


func gegner(id: StringName) -> TableRow:
	return row("gegner", id)


func gegner_stufenwerte(stufe: int) -> TableRow:
	return row("gegner_stufenwerte", stufe)


func gegner_rang(rang: String) -> TableRow:
	return row("gegner_raenge", rang)


## Übungspuppe (#31) aus uebungspuppen.csv oder null.
func uebungspuppe(id: StringName) -> TableRow:
	return row("uebungspuppen", id)


## Schadensschule (#32) aus schadensschulen.csv oder null.
func schadensschule(id: StringName) -> TableRow:
	return row("schadensschulen", id)


## Anzeigename einer Schadensschule (die ID, falls sie fehlt).
func schulname(id: StringName) -> String:
	var r := schadensschule(id)
	return String(r.get_value("name", id)) if r != null else String(id)


## Alle Schadensschulen, sortiert nach Reihenfolge.
func schadensschulen() -> Array[TableRow]:
	var result: Array[TableRow] = []
	result.assign(rows("schadensschulen"))
	result.sort_custom(func(a: TableRow, b: TableRow) -> bool:
		return int(a.get_value("reihenfolge", 0)) < int(b.get_value("reihenfolge", 0)))
	return result


func gebiet(id: StringName) -> TableRow:
	return row("gebiete", id)


func spawngruppe(id: StringName) -> TableRow:
	return row("spawngruppen", id)


## Alle Einträge einer Beutetabelle (Zeilen mit gleicher Spalte „tabelle“).
func beutetabelle(id: StringName) -> Array[TableRow]:
	return rows_where("beutetabellen", "tabelle", id)


func familienbeute(familie: String) -> TableRow:
	return row("familienbeute", familie)


func weltbeute(rang: String) -> Array[TableRow]:
	return rows_where("weltbeute", "rang", rang)


func gegenstand(id: StringName) -> TableRow:
	return row("gegenstaende", id)


## Alle Waren eines Händlers.
func haendler(id: StringName) -> Array[TableRow]:
	return rows_where("haendler", "haendler", id)


func klassenwachstum(klasse: StringName, stufe: int) -> TableRow:
	return row("klassenwachstum", [klasse, stufe])


## Werte einer Klasse auf einer Stufe (Wertesystem #19): Summe aller Zeilen
## von klassenwachstum.csv bis einschließlich stufe (Stufe 1 = Grundwerte).
## Ergebnis: Spaltenname → Zahl, z. B. {"staerke": 24, "leben": 110, …}.
## Fehlende Stufen zählen als 0.
func klassenwerte(klasse: StringName, stufe: int) -> Dictionary:
	_ensure_loaded()
	var schema: TableSchema = _data.schemas.get("klassenwachstum")
	var result := {}
	if schema == null:
		return result
	for column in schema.columns:
		if column.type == ColumnSchema.Type.INT and column.name != "stufe":
			result[column.name] = 0
	for r in rows_where("klassenwachstum", "klasse", klasse):
		if int(r.get_value("stufe", 0)) > stufe:
			continue
		for column_name: String in result:
			result[column_name] += int(r.get_value(column_name, 0))
	return result


## Umrechnung der Wertungen in Prozent für eine Stufe (umrechnung.csv) oder
## null. Fehlt die Stufe, gilt die höchste vorhandene darunter.
func umrechnung(stufe: int) -> TableRow:
	var r := row("umrechnung", stufe)
	if r != null:
		return r
	var best: TableRow = null
	for candidate: TableRow in rows("umrechnung"):
		var s := int(candidate.get_value("stufe", 0))
		if s <= stufe and (best == null or s > int(best.get_value("stufe", 0))):
			best = candidate
	return best


## Höchste Stufe in umrechnung.csv (für den Stufenregler im Entwickler-Panel).
func hoechste_stufe() -> int:
	var result := 1
	for r: TableRow in rows("umrechnung"):
		result = maxi(result, int(r.get_value("stufe", 1)))
	return result


## Benötigte Erfahrung für die nächste Stufe; -1, wenn die Stufe fehlt.
func erfahrung(stufe: int) -> int:
	var r := row("erfahrung", stufe)
	return r.get_value("benoetigte_erfahrung", -1) if r != null else -1


## Zahlenwerte einer Fähigkeit (Zeile in faehigkeitswerte.csv) oder null.
func faehigkeitswerte(id: StringName) -> TableRow:
	return row("faehigkeitswerte", id)


## Ein Wert einer Fähigkeit: Spaltenname (z. B. „abklingzeit“) oder
## „werte.<schluessel>“ für die Werte-Paare (z. B. „werte.radius“).
## So holen die .tres der Fähigkeiten (#21/#33) ihre Zahlen aus der Tabelle.
func faehigkeitswert(id: StringName, key: String, fallback: Variant = null) -> Variant:
	var r := faehigkeitswerte(id)
	if r == null:
		return fallback
	if key.begins_with("werte."):
		var pairs: Dictionary = r.get_value("werte", {})
		return pairs.get(key.substr(6), fallback)
	return r.get_value(key, fallback)


## Platzhalter-Waffe (#33) aus platzhalterwaffen.csv oder null, bis
## Ausrüstung kommt (#29): haupthand, nebenhand, fernkampf, unbewaffnet.
func platzhalterwaffe(id: StringName) -> TableRow:
	return row("platzhalterwaffen", id)


## Spielkonstante aus spielkonstanten.csv (z. B. „gcd“).
func konstante(key: StringName, fallback := 0.0) -> float:
	var r := row("spielkonstanten", key)
	return r.get_value("wert", fallback) if r != null else fallback


## Alle Völker, sortiert nach Reihenfolge.
func voelker() -> Array[RaceData]:
	_ensure_loaded()
	return _data.races


## Volk zur ID oder null.
func volk(id: StringName) -> RaceData:
	for race in voelker():
		if race.id == id:
			return race
	return null


# --- Intern ------------------------------------------------------------------

func _ensure_loaded() -> void:
	if _data != null:
		return
	_data = DataSet.load_all(SCHEMA_DIR, TABLE_DIR)
	_last_errors = _data.errors
	_valid = _data.is_valid()
	if _valid:
		print("Daten: %d Tabellen geladen (Prüfsumme %s)." % [_data.schemas.size(), short_checksum()])
	else:
		_print_errors(_data.errors)


func _print_errors(errors: Array[DataError]) -> void:
	printerr("Daten: %d Fehler in den Tabellen:" % errors.size())
	for e in errors:
		printerr("  " + e.to_text())


func _run_command_line(check: bool, doc: bool) -> void:
	var code := 0
	if doc:
		var path := ProjectSettings.globalize_path("res://").path_join(DOC_PATH).simplify_path()
		var problem := DataDocWriter.write(_data.schemas, path)
		if problem != "":
			printerr("Daten-Doku: " + problem)
			code = 1
		else:
			print("Daten-Doku geschrieben: " + path)
	if check:
		if _valid:
			print("Datenprüfung: alles in Ordnung (%d Tabellen, Prüfsumme %s)." % [_data.schemas.size(), short_checksum()])
		else:
			print("Datenprüfung: %d Fehler gefunden (Liste oben)." % _last_errors.size())
			code = 1
	get_tree().quit(code)
