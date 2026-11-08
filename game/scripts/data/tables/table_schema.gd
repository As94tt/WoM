class_name TableSchema
extends Resource
## Schema einer Datentabelle (Ticket #39). Ein Schema pro Tabelle liegt in
## res://data/schemas/<tabelle>.tres; die Tabelle selbst in
## res://data/tables/<tabelle>.csv. Neue Tabellen entstehen, indem man ein
## Schema und die passende CSV-Datei anlegt (siehe docs/DATENTABELLEN.md).

## Name der Tabelle = Dateiname ohne .csv (z. B. „gegner“).
@export var table: String
## Überschrift in der Dokumentation (z. B. „Gegner“).
@export var title: String
## Gruppe in der Dokumentation (z. B. „Gegner“, „Welt“, „Beute“).
@export var group: String
## Kurze Erklärung für die Dokumentation.
@export_multiline var description := ""
## Spalten, deren Werte zusammen eindeutig sein müssen (meist nur „id“).
## Leer = Zeilen müssen nicht eindeutig sein (z. B. Beutetabellen).
@export var key_columns: PackedStringArray = []
## Optional: Ordner mit .tres-Daten (Feld „id“), für die es jeweils eine
## Zeile geben muss (z. B. Fähigkeitswerte zu jeder Fähigkeit).
@export var covers_folder := ""
## Reihenfolge in der Dokumentation.
@export var order := 0
@export var columns: Array[ColumnSchema] = []

## Name der Spalte für freie Anmerkungen; jede Tabelle hat sie, das Spiel
## ignoriert sie.
const NOTE_COLUMN := "notiz"


## Dateiname der Tabelle, z. B. „gegner.csv“.
func file_name() -> String:
	return table + ".csv"


func get_column(column_name: String) -> ColumnSchema:
	for column in columns:
		if column.name == column_name:
			return column
	return null
