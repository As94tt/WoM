class_name TableReader
extends RefCounted
## Liest eine CSV-Tabelle nach ihrem Schema (Ticket #39): Semikolon als
## Trennzeichen, UTF-8 mit oder ohne BOM, erste Zeile Spaltennamen, Zeilen
## mit # am Anfang und leere Zeilen werden übersprungen. Jede Zelle wird in
## den Typ laut Schema umgewandelt und geprüft (Pflichtfeld, Typ, Bereich,
## Auswahlwerte, ID-Format). Verweise zwischen Tabellen prüft DataSet.
##
## Zum Lesen der Zeilen dient FileAccess.get_csv_line (kein eigener Parser);
## Anführungszeichen, wie Excel und LibreOffice sie setzen, sind damit erlaubt.

const DELIMITER := ";"
const LIST_SEPARATOR := "|"
const PAIR_SEPARATOR := ":"
const COMMENT_PREFIX := "#"
const TRUE_WORDS: PackedStringArray = ["ja", "wahr", "true", "1", "x"]
const FALSE_WORDS: PackedStringArray = ["nein", "falsch", "false", "0"]

static var _id_regex: RegEx = null

## Ergebnis: geprüfte Zeilen und gefundene Fehler.
var rows: Array[TableRow] = []
var errors: Array[DataError] = []
## Zeilen mit Fehlern (nur für die Prüfung auf doppelte Schlüssel).
var rejected_rows: Array[TableRow] = []

var _schema: TableSchema
var _file: String


## Liest die Tabelle des Schemas aus dem Ordner table_dir.
static func read(schema: TableSchema, table_dir: String) -> TableReader:
	var reader := TableReader.new()
	reader._schema = schema
	reader._file = schema.file_name()
	reader._read(table_dir.path_join(schema.file_name()))
	return reader


## true, wenn text eine gültige ID ist (Kleinbuchstaben, Ziffern, _).
static func is_valid_id(text: String) -> bool:
	if _id_regex == null:
		_id_regex = RegEx.create_from_string("^[a-z0-9_]+$")
	return _id_regex.search(text) != null


## Wandelt den Text einer Zelle um. Gibt [Wert, Fehlertext] zurück;
## Fehlertext leer = in Ordnung. Leere Zellen behandelt der Aufrufer.
static func parse_value(column: ColumnSchema, text: String) -> Array:
	match column.type:
		ColumnSchema.Type.LIST:
			var items: Array = []
			for part in text.split(LIST_SEPARATOR):
				var item := part.strip_edges()
				if item == "":
					continue
				var parsed := _parse_single(column, column.item_type, item, true)
				if parsed[1] != "":
					return [null, "Listeneintrag ‚%s‘: %s" % [item, parsed[1]]]
				items.append(parsed[0])
			return [items, ""]
		ColumnSchema.Type.PAIRS:
			var pairs: Dictionary = {}
			for part in text.split(LIST_SEPARATOR):
				var pair := part.strip_edges()
				if pair == "":
					continue
				var sep := pair.find(PAIR_SEPARATOR)
				if sep <= 0:
					return [null, "‚%s‘ ist kein Werte-Paar (Schreibweise schluessel:wert)" % pair]
				var key := pair.substr(0, sep).strip_edges()
				var value_text := pair.substr(sep + 1).strip_edges()
				if not is_valid_id(key):
					return [null, "Schlüssel ‚%s‘ ist keine gültige ID (nur Kleinbuchstaben, Ziffern und _)" % key]
				if pairs.has(key):
					return [null, "Schlüssel ‚%s‘ kommt doppelt vor" % key]
				if value_text == "":
					return [null, "Werte-Paar ‚%s‘ hat keinen Wert" % pair]
				var parsed := _parse_single(column, column.item_type, value_text, true)
				if parsed[1] != "":
					return [null, "Wert von ‚%s‘: %s" % [key, parsed[1]]]
				pairs[key] = parsed[0]
			return [pairs, ""]
	return _parse_single(column, column.type, text, false)


## Grundwert einer leeren Zelle laut Schema. Gibt [Wert, Fehlertext] zurück.
static func default_for(column: ColumnSchema) -> Array:
	if column.default_value != "":
		return parse_value(column, column.default_value)
	match column.type:
		ColumnSchema.Type.INT: return [0, ""]
		ColumnSchema.Type.FLOAT: return [0.0, ""]
		ColumnSchema.Type.BOOL: return [false, ""]
		ColumnSchema.Type.LIST: return [[], ""]
		ColumnSchema.Type.PAIRS: return [{}, ""]
		ColumnSchema.Type.COLOR: return [Color(), ""]
	return ["", ""]


## Ein einzelner Wert (auch ein Listenelement oder Paar-Wert).
static func _parse_single(column: ColumnSchema, type: ColumnSchema.Type, text: String,
		is_item: bool) -> Array:
	match type:
		ColumnSchema.Type.TEXT:
			return [text, ""]
		ColumnSchema.Type.ID, ColumnSchema.Type.REF:
			var id_text := text
			# Zweiter Verweis mit Vorsilbe, z. B. „tabelle:beute_wolf“.
			if column.ref_prefix != "" and text.begins_with(column.ref_prefix + PAIR_SEPARATOR):
				id_text = text.substr(column.ref_prefix.length() + 1)
			if not is_valid_id(id_text):
				return [null, "‚%s‘ ist keine gültige ID (nur Kleinbuchstaben, Ziffern und _)" % text]
			return [text, ""]
		ColumnSchema.Type.INT:
			var int_text := text.trim_prefix("+")
			if not int_text.is_valid_int():
				return [null, "‚%s‘ ist keine Ganzzahl" % text]
			var value := int_text.to_int()
			var range_error := _check_range(column, value)
			return [value, range_error]
		ColumnSchema.Type.FLOAT:
			var float_text := text.trim_prefix("+").replace(",", ".")
			if not float_text.is_valid_float():
				return [null, "‚%s‘ ist keine Zahl" % text]
			var value := float_text.to_float()
			var range_error := _check_range(column, value)
			return [value, range_error]
		ColumnSchema.Type.BOOL:
			var word := text.to_lower()
			if TRUE_WORDS.has(word):
				return [true, ""]
			if FALSE_WORDS.has(word):
				return [false, ""]
			return [null, "‚%s‘ ist kein Ja/Nein-Wert (erlaubt: ja, nein)" % text]
		ColumnSchema.Type.CHOICE:
			if not column.choices.has(text):
				return [null, "‚%s‘ ist nicht erlaubt (erlaubt: %s)" % [text, ", ".join(column.choices)]]
			return [text, ""]
		ColumnSchema.Type.COLOR:
			if not Color.html_is_valid(text):
				return [null, "‚%s‘ ist keine Farbe (Schreibweise #rrggbb)" % text]
			return [Color.html(text), ""]
		ColumnSchema.Type.LIST, ColumnSchema.Type.PAIRS:
			if is_item:
				return [null, "Listen in Listen sind nicht erlaubt (Schema prüfen)"]
	return [null, "unbekannter Typ im Schema"]


static func _check_range(column: ColumnSchema, value: float) -> String:
	if column.has_min and value < column.min_value:
		return "%s ist kleiner als das Minimum %s" % [_num(value), _num(column.min_value)]
	if column.has_max and value > column.max_value:
		return "%s ist größer als das Maximum %s" % [_num(value), _num(column.max_value)]
	return ""


## Zahl ohne überflüssige Nachkommastellen, mit Komma (wie in den Tabellen).
static func _num(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return str(value).replace(".", ",")


# --- Lesen -------------------------------------------------------------------

func _read(path: String) -> void:
	if not FileAccess.file_exists(path):
		_error(0, "", "Die Datei fehlt (erwartet in %s)." % path.get_base_dir())
		return
	var bad_line := _first_invalid_utf8_line(FileAccess.get_file_as_bytes(path))
	if bad_line > 0:
		_error(bad_line, "", "Die Datei ist nicht als UTF-8 gespeichert (Umlaute kaputt). Bitte als „CSV UTF-8“ speichern.")
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		_error(0, "", "Die Datei lässt sich nicht öffnen (%s)." % error_string(FileAccess.get_open_error()))
		return

	var header: Dictionary = {}  # Spaltenname → Index
	var header_cells := 0
	var line := 0
	var first_record := true
	while f.get_position() < f.get_length():
		var start_line := line + 1
		var cells := f.get_csv_line(DELIMITER)
		line += 1
		for cell in cells:
			line += cell.count("\n")
		if first_record:
			first_record = false
			if cells.size() > 0:
				cells[0] = cells[0].trim_prefix("﻿")
		for i in cells.size():
			cells[i] = cells[i].strip_edges()
		if _is_blank_or_comment(cells):
			continue
		if header.is_empty():
			header_cells = cells.size()
			if not _read_header(cells, start_line, header):
				return
			continue
		_read_row(cells, start_line, header, header_cells)
	if header.is_empty():
		_error(0, "", "Die Datei hat keine Kopfzeile mit Spaltennamen.")


static func _is_blank_or_comment(cells: PackedStringArray) -> bool:
	if cells.is_empty():
		return true
	if cells[0].begins_with(COMMENT_PREFIX):
		return true
	for cell in cells:
		if cell != "":
			return false
	return true


func _read_header(cells: PackedStringArray, line: int, header: Dictionary) -> bool:
	var ok := true
	for i in cells.size():
		var col_name := cells[i]
		if col_name == "":
			continue  # Leere Spalten am Ende (z. B. aus Excel) sind erlaubt.
		if header.has(col_name):
			_error(line, col_name, "Die Spalte steht doppelt in der Kopfzeile.")
			ok = false
			continue
		header[col_name] = i
		if col_name != TableSchema.NOTE_COLUMN and _schema.get_column(col_name) == null:
			_error(line, col_name, "Diese Spalte gibt es im Schema nicht (Tippfehler?).")
			ok = false
	for column in _schema.columns:
		if not header.has(column.name):
			_error(line, column.name, "Die Spalte fehlt in der Kopfzeile.")
			ok = false
	if not header.has(TableSchema.NOTE_COLUMN):
		_error(line, TableSchema.NOTE_COLUMN, "Die Spalte fehlt in der Kopfzeile (jede Tabelle hat eine Spalte „notiz“).")
		ok = false
	return ok


func _read_row(cells: PackedStringArray, line: int, header: Dictionary, header_cells: int) -> void:
	for i in range(header_cells, cells.size()):
		if cells[i] != "":
			_error(line, "", "Die Zeile hat mehr Zellen als die Kopfzeile Spalten (Semikolon im Text? Dann den Text in \"…\" setzen).")
			return
	var row := TableRow.new()
	row.table = _schema.table
	row.line = line
	var ok := true
	for column in _schema.columns:
		var index: int = header[column.name]
		var text := cells[index] if index < cells.size() else ""
		var result: Array
		if text == "":
			if column.required:
				_error(line, column.name, "Pflichtfeld ist leer.")
				ok = false
				continue
			row.blank_columns[column.name] = true
			result = default_for(column)
			if result[1] != "":
				_error(line, column.name, "Standardwert im Schema ungültig: %s" % result[1])
				ok = false
				continue
		else:
			result = parse_value(column, text)
			if result[1] != "":
				_error(line, column.name, result[1] + ".")
				ok = false
				continue
		row.values[column.name] = result[0]
	if ok:
		rows.append(row)
	else:
		# Fehlerhafte Zeilen zählen trotzdem bei der Prüfung auf doppelte
		# Schlüssel mit, damit nicht erst der nächste Durchlauf sie meldet.
		rejected_rows.append(row)


func _error(line: int, column: String, message: String) -> void:
	errors.append(DataError.create(_file, line, column, message))


## Zeilennummer des ersten ungültigen UTF-8-Zeichens, 0 = alles in Ordnung.
## Excel speichert „CSV (Trennzeichen-getrennt)“ in Windows-1252; dann kommen
## Umlaute hier als ungültige Bytes an.
static func _first_invalid_utf8_line(bytes: PackedByteArray) -> int:
	var line := 1
	var i := 0
	var n := bytes.size()
	while i < n:
		var b := bytes[i]
		if b == 10:
			line += 1
		var extra := 0
		if b < 0x80:
			extra = 0
		elif b >= 0xC2 and b <= 0xDF:
			extra = 1
		elif b >= 0xE0 and b <= 0xEF:
			extra = 2
		elif b >= 0xF0 and b <= 0xF4:
			extra = 3
		else:
			return line
		if i + extra >= n:
			return line
		for k in range(1, extra + 1):
			if bytes[i + k] & 0xC0 != 0x80:
				return line
		i += extra + 1
	return 0
