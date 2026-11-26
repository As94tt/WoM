class_name ResourceEffect
extends EffectData
## Effekt „Ressource ändern“ (Ticket #32), z. B. +10 Chi, −20 Wut, +5 % Mana.
## Negativ entzieht höchstens, was da ist; die entzogene Menge steht danach
## in ctx.consumed[resource] (z. B. für „Schaden je verbrauchter Wut“).
## Ressourcen: mana, rage, energy, chi (CharacterStats.RESOURCE_IDS).
##
## Seit #53: Mit amount_key kommt die Menge aus faehigkeitswerte.csv (z. B.
## „werte.wut“: Hieb erzeugt 10 Wut), inklusive Veränderungen durch Talente
## (Schildmeister: Schildschlag erzeugt 25 statt 15 Wut). Die Zeile bestimmt
## EffectValues (values_ability, Fähigkeit im Kontext, auslösende Aura).

@export var resource: StringName = &"mana"
## Menge (negativ = entziehen).
@export var amount := 0.0
## Menge in Prozent des Maximums statt in Punkten.
@export var percent_of_max := false
## Alles entziehen, was da ist (amount wird ignoriert).
@export var remove_all := false
## Menge aus faehigkeitswerte.csv statt amount (Spalte oder „werte.<schlüssel>“);
## leer = amount.
@export var amount_key := ""
## Zeile für amount_key (leer = Fähigkeit im Kontext bzw. auslösende Aura).
@export var values_ability: AbilityData


func _apply(ctx: EffectContext, target: Unit) -> void:
	var stats := target.get_stats()
	if stats == null:
		return
	var delta := get_amount(ctx)
	if percent_of_max:
		delta = stats.get_resource_max(resource) * delta / 100.0
	if remove_all:
		delta = -stats.get_resource(resource)
	elif delta > 0.0:
		delta = scale_amount(delta, ctx, target)
	if is_zero_approx(delta):
		return
	var changed := stats.change_resource(resource, delta)
	if changed < 0.0:
		var key := String(resource)
		ctx.consumed[key] = float(ctx.consumed.get(key, 0.0)) - changed


## Menge vor Skalierung (Feld oder Tabelle).
func get_amount(ctx: EffectContext) -> float:
	if amount_key == "":
		return amount
	return EffectValues.number(ctx, values_ability, amount_key, amount)


func describe() -> String:
	if amount_key != "":
		return "%s (%s)" % [resource, amount_key]
	return "%s %+d%s" % [resource, int(amount), " %" if percent_of_max else ""]
