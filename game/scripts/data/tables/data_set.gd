class_name DataSet
extends RefCounted
## Ein vollständig geladener Stand aller Datentabellen (Ticket #39). Lädt alle
## Schemas aus res://data/schemas/, liest die passenden CSV-Dateien, prüft
## sie und stellt die Zeilen bereit. Der Autoload „Data“ hält den aktiven
## Stand; beim Neuladen entsteht ein neuer DataSet, der den alten nur ersetzt,
## wenn er fehlerfrei ist.
##
## Prüfungen über einzelne Zellen hinaus:
## - eindeutige Schlüssel (key_columns)
## - Verweise auf Tabellen und auf .tres-Ordner (Ordner ohne Daten: nur Format)
## - Endlosschleifen bei verschachtelten Verweisen auf die eigene Tabelle
## - covers_folder: zu jeder .tres im Ordner gibt es eine Zeile

## Schlüssel mehrerer Spalten werden mit diesem Zeichen verbunden.
const KEY_JOIN := "|"

## Tabelle → Schema.
var schemas: Dictionary[String, TableSchema] = {}
## Tabelle → Zeilen in Dateireihenfolge.
var tables: Dictionary[String, Array] = {}
## Gefundene Fehler (leer = Stand ist gültig).
var errors: Array[DataError] = []
## Prüfsumme über alle Tabelleninhalte (ohne Kommentare und Notizen).
var checksum := ""
## Völker als typisierte Objekte, sortiert nach Reihenfolge.
var races: Array[RaceData] = []

## Tabelle → Schlüssel → Zeile.
var _index: Dictionary[String, Dictionary] = {}
## Ordner → { id: true } oder leer, wenn der Ordner keine Daten hat.
var _folder_ids: Dictionary[String, Dictionary] = {}
## "tabelle.spalte" → { Wert: true }.
var _column_values: Dictionary[String, Dictionary] = {}
## Tabelle → Zeilen mit Fehlern (nur für die Prüfung doppelter Schlüssel).
var _rejected: Dictionary[String, Array] = {}


## Lädt und prüft alle Tabellen.
static func load_all(schema_dir: String, table_dir: String) -> DataSet:
	var data_set := DataSet.new()
	data_set._load_schemas(schema_dir)
	for table in data_set._sorted_tables():
		var reader := TableReader.read(data_set.schemas[table], table_dir)
		data_set.tables[table] = reader.rows
		data_set._rejected[table] = reader.rejected_rows
		data_set.errors.append_array(reader.errors)
	for table in data_set._sorted_tables():
		data_set._build_index(table)
	for table in data_set._sorted_tables():
		data_set._check_references(table)
		data_set._check_cycles(table)
		data_set._check_coverage(table)
	data_set.checksum = data_set._compute_checksum()
	data_set._build_typed()
	return data_set


func is_valid() -> bool:
	return errors.is_empty()


## Alle Zeilen einer Tabelle (leer, wenn es sie nicht gibt).
func get_rows(table: String) -> Array:
	return tables.get(table, [])


## Zeile zum Schlüssel oder null. Bei mehreren Schlüsselspalten ein Array
## mit den Werten in Schema-Reihenfolge, z. B. [&"warrior", 5].
func get_row(table: String, key: Variant) -> TableRow:
	var index: Dictionary = _index.get(table, {})
	var key_text: String
	if key is Array:
		var parts: PackedStringArray = []
		for part in key:
			parts.append(str(part))
		key_text = KEY_JOIN.join(parts)
	else:
		key_text = str(key)
	return index.get(key_text)


## Alle Zeilen, deren Spalte column den Wert value hat.
func get_rows_where(table: String, column: String, value: Variant) -> Array[TableRow]:
	var result: Array[TableRow] = []
	var wanted := str(value)
	for row: TableRow in get_rows(table):
		if str(row.get_value(column)) == wanted:
			result.append(row)
	return result


# --- Schemas -----------------------------------------------------------------

func _load_schemas(schema_dir: String) -> void:
	var files := ResourceLoader.list_directory(schema_dir)
	files.sort()
	for file in files:
		if not file.ends_with(".tres"):
			continue
		var schema := load(schema_dir.path_join(file)) as TableSchema
		if schema == null:
			_add_error(file, 0, "", "Kein gültiges Tabellenschema (TableSchema).")
			continue
		if schema.table == "" or schemas.has(schema.table):
			_add_error(file, 0, "", "Tabellenname fehlt oder ist doppelt („%s“)." % schema.table)
			continue
		schemas[schema.table] = schema
	if schemas.is_empty():
		_add_error(schema_dir, 0, "", "Keine Tabellenschemas gefunden.")
	for table in _sorted_tables():
		_check_schema(schemas[table])


## Prüft das Schema selbst, damit Fehler beim Anlegen neuer Tabellen
## verständlich gemeldet werden.
func _check_schema(schema: TableSchema) -> void:
	var file := "schemas/%s.tres" % schema.table
	for key in schema.key_columns:
		if schema.get_column(key) == null:
			_add_error(file, 0, key, "Schlüsselspalte gibt es im Schema nicht.")
	for column in schema.columns:
		if column.name == TableSchema.NOTE_COLUMN:
			_add_error(file, 0, column.name, "„notiz“ ist immer vorhanden und gehört nicht ins Schema.")
		var uses_choices := column.type == ColumnSchema.Type.CHOICE \
				or (column.type == ColumnSchema.Type.LIST and column.item_type == ColumnSchema.Type.CHOICE)
		if uses_choices and column.choices.is_empty():
			_add_error(file, 0, column.name, "Auswahl ohne erlaubte Werte.")
		for target in [column.ref_table, column.prefix_table]:
			if target != "" and not schemas.has(target):
				_add_error(file, 0, column.name, "Verweis auf unbekannte Tabelle „%s“." % target)


func _sorted_tables() -> Array[String]:
	var names: Array[String] = []
	names.assign(schemas.keys())
	names.sort()
	return names


# --- Schlüssel ---------------------------------------------------------------

func _build_index(table: String) -> void:
	var schema := schemas[table]
	var index: Dictionary = {}
	_index[table] = index
	if schema.key_columns.is_empty():
		return
	var all_rows: Array = tables[table] + _rejected.get(table, [])
	all_rows.sort_custom(func(a: TableRow, b: TableRow) -> bool: return a.line < b.line)
	var seen: Dictionary = {}  # Schlüssel → Zeile
	for row: TableRow in all_rows:
		if not row.values.has_all(Array(schema.key_columns)):
			continue  # Schlüssel selbst fehlerhaft, schon gemeldet.
		var key := _row_key(schema, row)
		if seen.has(key):
			var first: TableRow = seen[key]
			var what := "ID" if schema.key_columns.size() == 1 else "Kombination %s" % "/".join(schema.key_columns)
			_add_error(schema.file_name(), row.line, schema.key_columns[0],
					"%s ‚%s‘ gibt es schon in Zeile %d." % [what, key, first.line])
			continue
		seen[key] = row
		if not _rejected.get(table, []).has(row):
			index[key] = row


static func _row_key(schema: TableSchema, row: TableRow) -> String:
	var parts: PackedStringArray = []
	for key in schema.key_columns:
		parts.append(str(row.get_value(key)))
	return KEY_JOIN.join(parts)


# --- Verweise ----------------------------------------------------------------

func _check_references(table: String) -> void:
	var schema := schemas[table]
	for column in schema.columns:
		if not column.is_reference() and column.ref_prefix == "":
			continue
		for row: TableRow in tables[table]:
			if row.is_blank(column.name):
				continue
			for target_id in _referenced_ids(column, row.get_value(column.name)):
				var problem := _check_reference(column, target_id)
				if problem != "":
					_add_error(schema.file_name(), row.line, column.name, problem)


## Die IDs, auf die eine Zelle verweist (Einzelwert, Listenelemente oder
## Schlüssel der Werte-Paare).
static func _referenced_ids(column: ColumnSchema, value: Variant) -> Array:
	match column.type:
		ColumnSchema.Type.REF, ColumnSchema.Type.ID:
			return [value]
		ColumnSchema.Type.LIST:
			return value
		ColumnSchema.Type.PAIRS:
			return (value as Dictionary).keys()
	return []


## Leerer Text = Verweis in Ordnung, sonst die Fehlermeldung.
func _check_reference(column: ColumnSchema, value: String) -> String:
	var label := column.ref_label if column.ref_label != "" else "Eintrag"
	if column.ref_prefix != "" and value.begins_with(column.ref_prefix + TableReader.PAIR_SEPARATOR):
		var target_id := value.substr(column.ref_prefix.length() + 1)
		if not _has_table_value(column.prefix_table, column.prefix_column, target_id):
			return "%s ‚%s‘ gibt es in %s.csv nicht." % [column.ref_prefix.capitalize(), target_id, column.prefix_table]
		return ""
	if column.ref_table != "":
		if not _has_table_value(column.ref_table, column.ref_column, value):
			return "%s ‚%s‘ gibt es nicht (%s.csv)." % [label, value, column.ref_table]
	elif column.ref_folder != "":
		var ids := _get_folder_ids(column.ref_folder)
		# Ordner ohne Daten: Format wurde schon beim Lesen geprüft.
		if not ids.is_empty() and not ids.has(value):
			return "%s ‚%s‘ gibt es nicht (%s)." % [label, value, column.ref_folder]
	return ""


func _has_table_value(table: String, column_name: String, value: String) -> bool:
	if not schemas.has(table):
		return false
	var schema := schemas[table]
	var target := column_name
	if target == "":
		if schema.key_columns.size() == 1:
			return _index[table].has(value)
		target = schema.key_columns[0] if not schema.key_columns.is_empty() else ""
	var cache_key := table + "." + target
	if not _column_values.has(cache_key):
		var values: Dictionary = {}
		for row: TableRow in tables[table]:
			values[str(row.get_value(target))] = true
		_column_values[cache_key] = values
	return _column_values[cache_key].has(value)


## IDs aller .tres in einem Ordner (Feld „id“). Leer = keine Daten dieses Typs.
func _get_folder_ids(folder: String) -> Dictionary:
	if _folder_ids.has(folder):
		return _folder_ids[folder]
	var ids: Dictionary = {}
	if DirAccess.dir_exists_absolute(folder):
		for file in ResourceLoader.list_directory(folder):
			if not file.ends_with(".tres"):
				continue
			var res := load(folder.path_join(file))
			if res != null and res.get("id") != null:
				ids[str(res.get("id"))] = true
	_folder_ids[folder] = ids
	return ids


# --- Endlosschleifen ---------------------------------------------------------

## Verweist eine Spalte mit Vorsilbe auf die eigene Tabelle (z. B. Beute-
## tabellen, die andere Beutetabellen enthalten), darf kein Kreis entstehen.
func _check_cycles(table: String) -> void:
	var schema := schemas[table]
	for column in schema.columns:
		if column.ref_prefix == "" or column.prefix_table != table or column.prefix_column == "":
			continue
		var prefix := column.ref_prefix + TableReader.PAIR_SEPARATOR
		# Gruppe → [[Zielgruppe, Zeile], …]
		var edges: Dictionary = {}
		for row: TableRow in tables[table]:
			var value := str(row.get_value(column.name))
			if not value.begins_with(prefix):
				continue
			var from := str(row.get_value(column.prefix_column))
			if not edges.has(from):
				edges[from] = []
			edges[from].append([value.substr(prefix.length()), row])
		var state: Dictionary = {}  # Gruppe → 1 (in Arbeit) / 2 (fertig)
		var groups := edges.keys()
		groups.sort()
		for group in groups:
			_visit(group, edges, state, [], schema, column)


func _visit(group: String, edges: Dictionary, state: Dictionary, path: Array,
		schema: TableSchema, column: ColumnSchema) -> void:
	if state.get(group, 0) == 2:
		return
	state[group] = 1
	path.append(group)
	for edge in edges.get(group, []):
		var target: String = edge[0]
		var row: TableRow = edge[1]
		if state.get(target, 0) == 1:
			var circle: Array = path.slice(path.find(target))
			circle.append(target)
			_add_error(schema.file_name(), row.line, column.name,
					"Endlosschleife: %s." % " → ".join(PackedStringArray(circle)))
		elif state.get(target, 0) == 0:
			_visit(target, edges, state, path, schema, column)
	path.pop_back()
	state[group] = 2


# --- Vollständigkeit ---------------------------------------------------------

func _check_coverage(table: String) -> void:
	var schema := schemas[table]
	if schema.covers_folder == "" or schema.key_columns.is_empty():
		return
	var ids := _get_folder_ids(schema.covers_folder).keys()
	ids.sort()
	for id in ids:
		if not _index[table].has(id):
			_add_error(schema.file_name(), 0, schema.key_columns[0],
					"Zu ‚%s‘ (%s) fehlt eine Zeile." % [id, schema.covers_folder])


# --- Prüfsumme und typisierte Objekte ----------------------------------------

## SHA-256 über alle Tabellen in fester Reihenfolge, gebildet aus den
## umgewandelten Werten. Zeilenenden, BOM, Kommentarzeilen, Notizen und die
## Schreibweise von Zahlen (1,5 / 1.5) ändern die Prüfsumme daher nicht.
func _compute_checksum() -> String:
	var parts: PackedStringArray = []
	for table in _sorted_tables():
		var schema := schemas[table]
		parts.append("[%s]" % table)
		for row: TableRow in tables[table]:
			var cells: PackedStringArray = []
			for column in schema.columns:
				cells.append(var_to_str(row.get_value(column.name)))
			parts.append("\u001f".join(cells))
	return "\n".join(parts).sha256_text()


func _build_typed() -> void:
	for row: TableRow in get_rows("voelker"):
		races.append(RaceData.from_row(row))
	races.sort_custom(func(a: RaceData, b: RaceData) -> bool: return a.order < b.order)


func _add_error(file: String, line: int, column: String, message: String) -> void:
	errors.append(DataError.create(file, line, column, message))
