class_name ClassData
extends Resource
## Eine Grundklasse als Daten (Ticket #6). Die Datensätze liegen in
## res://data/classes/ und werden über GameData geladen. Ressource,
## Fähigkeiten und Rüstungsklasse kommen später als zusätzliche Felder dazu.

enum Role { DAMAGE, TANK, HEALER }

## Feste ID, unter der Charaktere die Klasse speichern (z. B. &"mage").
@export var id: StringName
## Anzeigename (z. B. „Magier“).
@export var display_name: String
## Kurzbeschreibung für die Charaktererstellung (#8). Platzhaltertext nach GDD.
@export_multiline var description: String
@export var role: Role = Role.DAMAGE
## Anzeigename der Rolle (z. B. „Schaden“).
@export var role_name: String
## Klassenfarbe für Klassennamen in der UI. Vorläufiger Wert, solange die
## Tokens class/* im UI-Styleguide TBD sind; wird dann durch sie ersetzt.
@export var color: Color = Color.WHITE
## Reihenfolge in Listen (GDD: Magier 1, Krieger 2, Druide 3, Schurke 4, Mönch 5).
@export var order: int = 0
