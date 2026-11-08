class_name ClassData
extends Resource
## Eine Grundklasse als Daten (Ticket #6). Die Datensätze liegen in
## res://data/classes/ und werden über GameData geladen. Fähigkeiten und
## Rüstungsklasse kommen später als zusätzliche Felder dazu.
##
## Wertesystem (#19): Hauptattribut, Kraftwert und Ressourcen legen fest,
## welche Formeln der Werte für die Klasse gelten (siehe StatRules). Die
## Zahlen je Stufe stehen in klassenwachstum.csv.

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

@export_group("Werte (#19)")
## Attribut, aus dem die Kampfkraft entsteht (StatDefinition-ID, z. B.
## &"strength" beim Krieger). Leer = keins.
@export var primary_attribute: StringName = &""
## Kraftwert der Klasse: &"attack_power" (Kampfkraft) oder &"spell_power"
## (Zaubermacht). Bestimmt, welcher der beiden Werte gilt und angezeigt wird.
## Die Sofortzauber des Mönchs skalieren deshalb mit Kampfkraft.
@export var power_stat: StringName = &""
## Ressourcen der Klasse in Anzeigereihenfolge (&"mana", &"rage", &"energy",
## &"chi"). Der Mönch hat zwei Leisten: Energie und Chi.
@export var resources: Array[StringName] = []
