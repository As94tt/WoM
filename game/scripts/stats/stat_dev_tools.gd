class_name StatDevTools
extends Resource
## Testwerte für den Abschnitt „Werte“ im Entwickler-Panel (Ticket #19).
## Liegt in res://data/stats/dev_tools.tres. Nur für Entwickler, kein Teil
## des Spiels.

## Testmodifikatoren, je einer als Schalter im Panel.
@export var test_modifiers: Array[StatModifierData] = []
## „Schaden nehmen“: Prozent des maximalen Lebens.
@export var damage_taken_percent := 20.0
## „Schaden austeilen“: Punkte (nur für Wut).
@export var damage_dealt := 100.0
## „Ressource verbrauchen“: Punkte Mana bzw. Energie.
@export var resource_spent := 30.0
## „Chi aufbauen“: Punkte Chi.
@export var chi_built := 25.0
