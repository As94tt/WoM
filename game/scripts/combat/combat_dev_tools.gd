class_name CombatDevTools
extends Resource
## Testeffekte und Testauren für den Abschnitt „Auren“ im Entwickler-Panel
## (Ticket #32). Liegt in res://data/combat/dev_tools.tres; die Testauren in
## res://data/auras/test_*.tres. Nur für Entwickler, kein Teil des Spiels:
## Bis Fähigkeiten gewirkt werden können (#33), testet man damit Effekte,
## Auren, Zustände, Auslöser und Anzeigen.

@export var entries: Array[CombatDevEntry] = []
## Betrag, mit dem „Ereignis auslösen“ die Auslöser füttert.
@export var event_amount := 100.0
## Fähigkeit für „Ereignis: Fähigkeit gewirkt“.
@export var event_ability_id: StringName = &"magisches_geschoss"
