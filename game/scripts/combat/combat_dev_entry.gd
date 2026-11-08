class_name CombatDevEntry
extends Resource
## Ein Eintrag im Abschnitt „Auren“ des Entwickler-Panels (Ticket #32): ein
## Button, der eine Effektliste mit der eigenen Figur als Wirker auf das Ziel
## (oder sich selbst) anwendet. Nur für Entwickler.

## Text des Buttons.
@export var label := ""
## Zwischenüberschrift (neue Gruppe, wenn sie sich ändert).
@export var group := ""
@export var effects: Array[EffectData] = []
