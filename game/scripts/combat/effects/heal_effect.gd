class_name HealEffect
extends AmountEffect
## Effekt „Heilung“ (Ticket #32): Menge wie Schaden, üblicherweise mit
## Zaubermacht (power_source = SPELL_POWER). Seit #34 mit Krit,
## Heilmodifikatoren und erfasster Überheilung (Combat.roll_heal).

func _apply(ctx: EffectContext, target: Unit) -> void:
	var flags := Combat.FLAG_PERIODIC if ctx.periodic else 0
	Combat.roll_heal(ctx.get_caster(), target, amount_for(ctx, target), ctx, flags)


func describe() -> String:
	return "Heilung %s" % StatFormat.grouped(base_amount)
