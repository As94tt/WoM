class_name RaceData
extends Resource
## Ein spielbares Volk als Daten (Ticket #6). Die Datensätze liegen in
## res://data/races/ und werden über GameData geladen. Volksfähigkeiten
## (dauerhafte Auren) kommen später als zusätzliche Felder dazu.

## Körperfamilien laut GDD. Für Rig, Animationen und Ausrüstung zählt die
## Körperfamilie, nicht das Volk.
enum BodyFamily { NORMAL, COMPACT, MASSIVE, HUNCHED }

## Feste ID, unter der Charaktere das Volk speichern (z. B. &"human").
@export var id: StringName
## Anzeigename (z. B. „Mensch“).
@export var display_name: String
@export var body_family: BodyFamily = BodyFamily.NORMAL
## Größenfaktor des Platzhaltermodells (Mensch = 1,0). Gilt für beide Geschlechter.
@export_range(0.5, 2.0, 0.05) var height_factor: float = 1.0
## Reihenfolge in Listen (GDD-Reihenfolge der Völker).
@export var order: int = 0
