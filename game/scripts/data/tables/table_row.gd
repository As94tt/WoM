class_name TableRow
extends RefCounted
## Eine geprüfte Zeile einer Datentabelle (Ticket #39), mit Werten im Typ
## laut Schema: Text, ID, Auswahl und Verweis als String, Ganzzahl als int,
## Kommazahl als float, Ja/Nein als bool, Farbe als Color, Liste als Array,
## Werte-Paare als Dictionary (Schlüssel String). Leere Zellen enthalten den
## Standardwert; ob eine Zelle leer war, sagt is_blank().
##
## Zugriff nur über den Autoload „Data“, z. B. Data.gegner(&"wolf_jung").

## Tabelle, aus der die Zeile stammt (z. B. „gegner“).
var table: String
## Zeilennummer in der CSV-Datei (für Meldungen).
var line: int
## Spaltenname → Wert.
var values: Dictionary = {}
## Spalten, deren Zelle leer war.
var blank_columns: Dictionary = {}


## Wert einer Spalte oder fallback, wenn es die Spalte nicht gibt.
func get_value(column: String, fallback: Variant = null) -> Variant:
	return values.get(column, fallback)


## true, wenn die Zelle leer war (z. B. „Waffenschaden wird berechnet“).
func is_blank(column: String) -> bool:
	return blank_columns.has(column)


## Kurzform für die Spalte „id“.
func id() -> String:
	return str(values.get("id", ""))


func _to_string() -> String:
	return "%s.csv Zeile %d %s" % [table, line, values]
