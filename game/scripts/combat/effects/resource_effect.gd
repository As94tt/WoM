class_name ResourceEffect
extends EffectData
## Effekt „Ressource ändern“ (Ticket #32), z. B. +10 Chi, −20 Wut, +5 % Mana.
## Negativ entzieht höchstens, was da ist; die entzogene Menge steht danach
## in ctx.consumed[resource] (z. B. für „Schaden je verbrauchter Wut“).
## Ressourcen: mana, rage, energy, chi (CharacterStats.RESOURCE_IDS).

@export var resource: StringName = &"mana"
## Menge (negativ = entziehen).
@export var amount := 0.0
## Menge in Prozent des Maximums statt in Punkten.
@export var percent_of_max := false
## Alles entziehen, was da ist (amount wird ignoriert).
@export var remove_all := false


func _apply(ctx: EffectContext, target: Unit) -> void:
	var stats := target.get_stats()
	if stats == null:
		return
	var delta := amount
	if percent_of_max:
		delta = stats.get_resource_max(resource) * amount / 100.0
	if remove_all:
		delta = -stats.get_resource(resource)
	elif delta > 0.0:
		delta = scale_amount(delta, ctx, target)
	var changed := stats.change_resource(resource, delta)
	if changed < 0.0:
		var key := String(resource)
		ctx.consumed[key] = float(ctx.consumed.get(key, 0.0)) - changed


func describe() -> String:
	return "%s %+d%s" % [resource, int(amount), " %" if percent_of_max else ""]
