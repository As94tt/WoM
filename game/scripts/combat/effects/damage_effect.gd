class_name DamageEffect
extends AmountEffect
## Effekt „Schaden“ (Ticket #32): Menge (siehe AmountEffect) in einer
## Schadensschule (ID aus schadensschulen.csv).

@export var school: StringName = &"physisch"


func _apply(ctx: EffectContext, target: Unit) -> void:
	if Data.schadensschule(school) == null:
		push_warning("DamageEffect: unbekannte Schadensschule „%s“ (schadensschulen.csv)." % school)
	var flags := Combat.FLAG_PERIODIC if ctx.periodic else 0
	Combat.deal_damage(ctx.get_caster(), target, amount_for(ctx, target), school, ctx, flags)


func describe() -> String:
	return "Schaden %s (%s)" % [StatFormat.grouped(base_amount), Data.schulname(school)]
