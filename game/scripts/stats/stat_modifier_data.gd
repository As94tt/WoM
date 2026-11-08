class_name StatModifierData
extends Resource
## Ein Modifikator als Daten (Ticket #19), z. B. in einer .tres für
## Testmodifikatoren, später in Auren (#32) oder Gegenständen (#29). Zur
## Laufzeit wird daraus mit to_modifier() ein StatModifier mit Quelle.

## ID des Werts (StatDefinition.id), z. B. &"strength".
@export var stat: StringName
@export var kind: StatModifier.Kind = StatModifier.Kind.FLAT
## Punkte bzw. Prozent (negativ = Malus).
@export var value: float = 0.0


func to_modifier(source: StringName, source_name: String) -> StatModifier:
	return StatModifier.create(source, source_name, stat, value, kind)
