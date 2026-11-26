class_name PercentHealEffect
extends EffectData
## Heilung in Prozent des maximalen Lebens des Ziels (seit #53), z. B.
## Standhaft (jeder Block heilt 1/2/3 %), Blutdurst (kritische Treffer heilen)
## und Siegesrausch (stirbt ein Ziel, heilt sich der Krieger um 20 %).
##
## Prozent aus percent bzw. faehigkeitswerte.csv (percent_key, Zeile nach
## EffectValues). Skalierungen des Effekts wirken als Faktor, z. B. „× Stapel
## der Talent-Aura“ für Ränge. Ohne Würfel und Krit (Combat.heal), damit eine
## Heilung aus „kritischer Treffer“ sich nicht selbst wieder auslöst.

@export var percent := 0.0
## Schlüssel in faehigkeitswerte.csv statt percent (leer = percent).
@export var percent_key := ""
## Zeile für percent_key (leer = Fähigkeit im Kontext bzw. auslösende Aura).
@export var values_ability: AbilityData


func _apply(ctx: EffectContext, target: Unit) -> void:
	var stats := target.get_stats()
	if stats == null or stats.max_health <= 0.0:
		return
	var amount := scale_amount(stats.max_health * get_percent(ctx) / 100.0, ctx, target)
	if amount > 0.0:
		Combat.heal(ctx.get_caster(), target, amount, ctx)


func get_percent(ctx: EffectContext) -> float:
	if percent_key == "":
		return percent
	return EffectValues.number(ctx, values_ability, percent_key, percent)


func describe() -> String:
	return "Heilung %s %% des Lebens" % (percent_key if percent_key != "" else StatFormat.number(percent, 0))
