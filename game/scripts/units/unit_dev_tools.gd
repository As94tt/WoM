class_name UnitDevTools
extends Resource
## Testwerte für den Abschnitt „Einheiten“ im Entwickler-Panel (Ticket #31).
## Liegt in res://data/units/dev_tools.tres. Nur für Entwickler, kein Teil des
## Spiels: Bis Schaden und Heilung aus #34 kommen, testet man damit Rahmen,
## Namensplaketten und Übungspuppen.

## „Ziel: Schaden“: Prozent des maximalen Lebens.
@export var damage_percent := 10.0
## „Ziel: Treffer“: feste Punkte Schaden.
@export var damage_flat := 1000.0
## „Ziel: Heilung“: Prozent des maximalen Lebens.
@export var heal_percent := 10.0
## Schalter „Dauerschaden“: Schaden je Sekunde.
@export var damage_per_second := 500.0
