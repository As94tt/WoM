class_name MageBlinkEffect
extends MovementEffect
## „Bewegung“ mit der Entfernung aus der Tabelle (Ticket #22, Klassen-
## Erweiterung nach #32): Magischer Schritt und seine Varianten springen
## werte.distanz Meter nach vorn (Art TELEPORT, Zielbestimmung „Wirker
## selbst“). Wände halten den Sprung auf (wie bei „Bewegung“).

## Zeile der Zahlen (leer = Fähigkeit im Kontext).
@export var values_ability: AbilityData
@export var distance_key := "werte.distanz"


func _apply(ctx: EffectContext, target: Unit) -> void:
	var saved := distance
	distance = get_distance(ctx)
	super._apply(ctx, target)
	distance = saved


func get_distance(ctx: EffectContext) -> float:
	var value := MageValues.number(ctx, values_ability, distance_key, distance)
	return value if value > 0.0 else distance
