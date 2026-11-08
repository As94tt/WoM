class_name ColumnSchema
extends Resource
## Eine Spalte einer Datentabelle (Ticket #39). Liegt als Unterobjekt in einem
## TableSchema (res://data/schemas/<tabelle>.tres) und legt fest, wie die
## Zellen dieser Spalte gelesen und geprüft werden. Aus den Schemas entsteht
## automatisch die Spaltenübersicht in docs/DATENTABELLEN.md (--daten-doku).

## Typ der Zellen.
## TEXT    – freier Text
## ID      – Kleinbuchstaben, Ziffern und _ (z. B. „wolf_jung“)
## INT     – Ganzzahl
## FLOAT   – Kommazahl, Komma oder Punkt als Dezimaltrennzeichen
## BOOL    – Ja/Nein (ja, nein, wahr, falsch, true, false, 1, 0)
## CHOICE  – genau einer der Werte aus choices
## REF     – Verweis über die ID auf eine Tabelle oder einen .tres-Ordner
## LIST    – Liste, getrennt mit |; Elemente vom Typ item_type
## PAIRS   – Werte-Paare schluessel:wert, getrennt mit |; Werte vom Typ item_type
## COLOR   – Farbe als Hex-Code (z. B. #8a6d3b)
enum Type { TEXT, ID, INT, FLOAT, BOOL, CHOICE, REF, LIST, PAIRS, COLOR }

## Spaltenname in der ersten Zeile der Tabelle.
@export var name: String
@export var type: Type = Type.TEXT
## Pflichtfeld: Die Zelle darf nicht leer sein.
@export var required := false
## Standardwert für leere Zellen, als Text in Tabellen-Schreibweise.
## Leer = Grundwert des Typs (leerer Text, 0, nein, leere Liste).
@export var default_value := ""
## Erlaubter Bereich für Zahlen (auch Listenelemente und Paar-Werte).
@export var has_min := false
@export var min_value := 0.0
@export var has_max := false
@export var max_value := 0.0
## Erlaubte Werte bei CHOICE (bei LIST mit item_type CHOICE: für die Elemente).
@export var choices: PackedStringArray = []
## Verweis (REF, LIST-Elemente, PAIRS-Schlüssel) auf eine Tabelle ...
@export var ref_table := ""
## ... und dort auf diese Spalte (leer = erste Schlüsselspalte der Tabelle).
@export var ref_column := ""
## Verweis auf .tres-Daten: Ordner, dessen Ressourcen ein Feld „id“ haben
## (z. B. res://data/classes/). Gibt es dort noch keine Daten, wird nur das
## Format der ID geprüft.
@export var ref_folder := ""
## Bezeichnung des Ziels in Meldungen, z. B. „Fähigkeit“ oder „Gegenstand“.
@export var ref_label := ""
## Optionaler zweiter Verweis mit Vorsilbe, z. B. „tabelle“: Der Wert
## „tabelle:<id>“ verweist dann auf prefix_table/prefix_column statt auf das
## normale Ziel. Verweist prefix_table auf die eigene Tabelle, wird auf
## Endlosschleifen geprüft (verschachtelte Beutetabellen).
@export var ref_prefix := ""
@export var prefix_table := ""
@export var prefix_column := ""
## Typ der Listenelemente (LIST) bzw. der Werte (PAIRS).
@export var item_type: Type = Type.TEXT
## Kurze Erklärung für die Dokumentation.
@export_multiline var description := ""


## true, wenn die Spalte (oder ihre Elemente/Schlüssel) auf etwas verweist.
func is_reference() -> bool:
	return ref_table != "" or ref_folder != ""


## Lesbarer Name des Typs für Dokumentation und Meldungen.
static func type_name(t: Type) -> String:
	match t:
		Type.TEXT: return "Text"
		Type.ID: return "ID"
		Type.INT: return "Ganzzahl"
		Type.FLOAT: return "Kommazahl"
		Type.BOOL: return "Ja/Nein"
		Type.CHOICE: return "Auswahl"
		Type.REF: return "Verweis"
		Type.LIST: return "Liste"
		Type.PAIRS: return "Werte-Paare"
		Type.COLOR: return "Farbe"
	return "?"
