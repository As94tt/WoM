class_name ApplyAuraEffect
extends EffectData
## Effekt „Aura anwenden“ (Ticket #32), auch „Stapel hinzufügen“ (stacks > 1
## bzw. erneutes Anwenden einer stapelnden Aura). Was beim erneuten Anwenden
## passiert, legt die Aura fest (AuraData.stack_mode).

@export var aura: AuraData
## So viele Stapel kommen dazu (höchstens bis AuraData.max_stacks).
@export_range(1, 99) var stacks := 1
## Dauer in Sekunden statt der Dauer der Aura (0 = Dauer der Aura).
@export var duration_override := 0.0


func _apply(ctx: EffectContext, target: Unit) -> void:
	if aura == null or target.get_combat() == null:
		return
	target.get_combat().apply_aura(aura, ctx.get_caster(), ctx, stacks, duration_override)


func describe() -> String:
	return "Aura %s" % (aura.display_name if aura != null else "?")
