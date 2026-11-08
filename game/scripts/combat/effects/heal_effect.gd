class_name HealEffect
extends AmountEffect
## Effekt „Heilung“ (Ticket #32): Menge wie Schaden, üblicherweise mit
## Zaubermacht (power_source = SPELL_POWER).

func _apply(ctx: EffectContext, target: Unit) -> void:
	var flags := Combat.FLAG_PERIODIC if ctx.periodic else 0
	Combat.heal(ctx.get_caster(), target, amount_for(ctx, target), ctx, flags)


func describe() -> String:
	return "Heilung %s" % StatFormat.grouped(base_amount)
