class_name DataError
extends RefCounted
## Ein Fehler in den Datentabellen (Ticket #39), mit Datei, Zeile, Spalte und
## Grund, z. B. „gegner.csv, Zeile 14, Spalte faehigkeiten: Fähigkeit
## ‚biss_stark‘ gibt es nicht“.

var file: String
## 0 = betrifft die ganze Datei.
var line: int
## Leer = betrifft die ganze Zeile bzw. Datei.
var column: String
var message: String


static func create(file_name: String, line_number: int, column_name: String, text: String) -> DataError:
	var e := DataError.new()
	e.file = file_name
	e.line = line_number
	e.column = column_name
	e.message = text
	return e


func to_text() -> String:
	var where := file
	if line > 0:
		where += ", Zeile %d" % line
	if column != "":
		where += ", Spalte %s" % column
	return "%s: %s" % [where, message]


func _to_string() -> String:
	return to_text()
