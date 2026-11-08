class_name PlaceholderKind
extends Resource
## Art eines Platzhalter-Pfahls in der Welt (Ticket #15), z. B. NPC, Spawn,
## Übungspuppe oder Boss. Datensätze in res://data/world/placeholders/.
## Platzhalter markieren Inhalte, deren System noch fehlt; spätere Tickets
## ersetzen sie.

## Feste ID (z. B. &"npc").
@export var id: StringName
## Vorsilbe der Beschriftung (z. B. „NPC“ → „NPC: Händlerin“).
@export var prefix: String
## Graubox-Farbe des Pfahls (Spielwelt-Farbe, keine UI-Farbe).
@export var color: Color = Color(0.8, 0.8, 0.8)
