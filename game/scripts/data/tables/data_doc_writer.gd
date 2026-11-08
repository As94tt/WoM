class_name DataDocWriter
extends RefCounted
## Erzeugt die Spaltenübersicht in docs/DATENTABELLEN.md aus den Schemas
## (Ticket #39, Startparameter --daten-doku). Nur der Bereich zwischen den
## beiden Markierungen wird ersetzt; die Anleitung davor und danach wird von
## Hand gepflegt.

const BEGIN_MARK := "<!-- SPALTEN-ANFANG: automatisch erzeugt mit --daten-doku, nicht von Hand ändern -->"
const END_MARK := "<!-- SPALTEN-ENDE -->"


## Schreibt die Übersicht in die Datei path. Gibt "" oder eine Fehlermeldung zurück.
static func write(schemas: Dictionary[String, TableSchema], path: String) -> String:
	var text := ""
	if FileAccess.file_exists(path):
		text = FileAccess.get_file_as_string(path)
	var generated := BEGIN_MARK + "\n\n" + build(schemas) + "\n" + END_MARK
	var begin := text.find(BEGIN_MARK)
	var end := text.find(END_MARK)
	if begin >= 0 and end > begin:
		text = text.substr(0, begin) + generated + text.substr(end + END_MARK.length())
	else:
		text = text.strip_edges(false, true) + ("\n\n" if text != "" else "") + generated + "\n"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return "Datei %s lässt sich nicht schreiben (%s)." % [path, error_string(FileAccess.get_open_error())]
	f.store_string(text)
	return ""


## Markdown mit allen Tabellen, nach Gruppe und Reihenfolge sortiert.
static func build(schemas: Dictionary[String, TableSchema]) -> String:
	var list: Array[TableSchema] = []
	list.assign(schemas.values())
	list.sort_custom(func(a: TableSchema, b: TableSchema) -> bool:
		return a.order < b.order if a.order != b.order else a.table < b.table)
	var out: PackedStringArray = []
	var group := ""
	for schema in list:
		if schema.group != group:
			group = schema.group
			out.append("### %s\n" % group)
		out.append(_table(schema))
	return "\n".join(out)


static func _table(schema: TableSchema) -> String:
	var out: PackedStringArray = []
	out.append("#### %s – %s\n" % [schema.file_name(), schema.title])
	if schema.description != "":
		out.append(schema.description.strip_edges() + "\n")
	if schema.key_columns.is_empty():
		out.append("Eindeutig: keine Vorgabe (mehrere Zeilen mit gleichen Werten erlaubt).\n")
	elif schema.key_columns.size() == 1:
		out.append("Eindeutig: `%s`.\n" % schema.key_columns[0])
	else:
		out.append("Eindeutig: die Kombination `%s`.\n" % "` + `".join(schema.key_columns))
	if schema.covers_folder != "":
		out.append("Zu jeder Ressource in `%s` muss es eine Zeile geben (sobald dort Daten liegen).\n" % schema.covers_folder)
	out.append("| Spalte | Typ | Pflicht | Standard | Erlaubt | Erklärung |")
	out.append("| --- | --- | --- | --- | --- | --- |")
	for column in schema.columns:
		out.append("| `%s` | %s | %s | %s | %s | %s |" % [
			column.name,
			_type_text(column),
			"ja" if column.required else "",
			_cell(column.default_value),
			_allowed_text(column),
			_cell(column.description),
		])
	out.append("| `notiz` | Text | | | | Freie Anmerkung, wird vom Spiel ignoriert. |")
	return "\n".join(out) + "\n"


static func _type_text(column: ColumnSchema) -> String:
	var t := ColumnSchema.type_name(column.type)
	if column.type == ColumnSchema.Type.LIST or column.type == ColumnSchema.Type.PAIRS:
		var item := ColumnSchema.type_name(column.item_type)
		if column.is_reference():
			item = "Verweis"
		t += " (%s)" % item if column.type == ColumnSchema.Type.LIST else " (Wert: %s)" % ColumnSchema.type_name(column.item_type)
	return t


static func _allowed_text(column: ColumnSchema) -> String:
	var parts: PackedStringArray = []
	if not column.choices.is_empty():
		parts.append(", ".join(PackedStringArray(Array(column.choices).map(func(c: String) -> String: return "`%s`" % c))))
	if column.has_min and column.has_max:
		parts.append("%s bis %s" % [TableReader._num(column.min_value), TableReader._num(column.max_value)])
	elif column.has_min:
		parts.append("ab %s" % TableReader._num(column.min_value))
	elif column.has_max:
		parts.append("bis %s" % TableReader._num(column.max_value))
	var target := ""
	if column.ref_table != "":
		target = "`%s.csv`%s" % [column.ref_table, " (Spalte `%s`)" % column.ref_column if column.ref_column != "" else ""]
	elif column.ref_folder != "":
		target = "`%s`" % column.ref_folder
	if target != "":
		var what := column.ref_label if column.ref_label != "" else "Eintrag"
		var prefix := "Schlüssel: " if column.type == ColumnSchema.Type.PAIRS else ""
		parts.append("%s%s aus %s" % [prefix, what, target])
	if column.ref_prefix != "":
		parts.append("oder `%s:<id>` aus `%s.csv`" % [column.ref_prefix, column.prefix_table])
	return _cell("; ".join(parts))


## Text für eine Tabellenzelle (keine senkrechten Striche, keine Zeilenumbrüche).
static func _cell(text: String) -> String:
	return text.strip_edges().replace("\n", " ").replace("|", "\\|")
