class_name MageAreaEffect
extends AreaEffect
## „Fläche erzeugen“ mit Zahlen aus der Tabelle (Ticket #22, Klassen-
## Erweiterung nach #32): Dauer, Radius und Abstand der Ticks kommen aus
## faehigkeitswerte.csv der Fähigkeit im Kontext (bzw. values_ability),
## inklusive Veränderungen durch Talente (Permafrost, Lawine, Kältefront,
## Absoluter Nullpunkt, Aschenregen). Ist die Dauer 0 (z. B. Aschenregen ohne
## Talent), entsteht keine Fläche.
##
## Sonst wie „Fläche erzeugen“: Der Host erzeugt eine GroundArea unter dem
## EffectSpawner, Clients sehen die Graubox-Scheibe.

## Zeile der Zahlen (leer = Fähigkeit im Kontext, siehe MageValues).
@export var values_ability: AbilityData
@export var duration_key := "werte.flaeche_dauer"
@export var radius_key := "werte.flaeche_radius"
@export var interval_key := "werte.flaeche_tick"
## Faktor aus Kette oder verbrauchten Stapeln (z. B. Brand-Explosion) nicht
## an die Effekte der Fläche weitergeben.
@export var reset_amount_factor := true


func _apply(ctx: EffectContext, target: Unit) -> void:
	var area_duration := _value(ctx, duration_key, duration)
	if area_duration <= 0.0:
		return
	var plain := AreaEffect.new()
	plain.duration = area_duration
	var values := get_values(ctx)
	plain.area_radius = values[1]
	plain.interval = values[2]
	plain.area_filter = area_filter
	plain.tick_on_create = tick_on_create
	plain.at_point = at_point
	plain.max_targets = max_targets
	plain.effects = effects
	var inner := ctx.copy()
	if values_ability != null:
		inner.ability = values_ability
	if reset_amount_factor:
		inner.amount_factor = 1.0
	plain._apply(inner, target)


## Werte für Anzeigen und Tests: [Dauer, Radius, Abstand der Ticks]. Radius
## und Abstand ohne Tabellenwert aus den Feldern.
func get_values(ctx: EffectContext) -> Array[float]:
	var radius_value := _value(ctx, radius_key, area_radius)
	var interval_value := _value(ctx, interval_key, interval)
	return [_value(ctx, duration_key, duration),
			radius_value if radius_value > 0.0 else area_radius,
			maxf(0.1, interval_value if interval_value > 0.0 else interval)]


func _value(ctx: EffectContext, key: String, fallback: float) -> float:
	if key == "":
		return fallback
	return MageValues.number(ctx, values_ability, key, fallback)


func describe() -> String:
	return "Fläche (Magier)"
