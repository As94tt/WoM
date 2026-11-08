class_name ThreatEffect
extends EffectData
## Effekt „Bedrohung ändern“ (Ticket #32, Platzhalter bis #35): Das Ziel
## merkt sich die Bedrohung des Wirkers (UnitCombat.add_threat), sie hat
## aber noch keine Wirkung. Das Entwickler-Panel zeigt sie an.

## Bedrohung in Punkten (negativ = senken).
@export var amount := 0.0


func _apply(ctx: EffectContext, target: Unit) -> void:
	Combat.add_threat(ctx.get_caster(), target, scale_amount(amount, ctx, target))


func describe() -> String:
	return "Bedrohung %+d" % int(amount)
