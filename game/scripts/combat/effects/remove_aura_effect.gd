class_name RemoveAuraEffect
extends EffectData
## Effekt „Aura entfernen“ bzw. „Stapel verbrauchen“ (Ticket #32). Die Zahl
## der entfernten Stapel steht danach in ctx.consumed["aura:<id>"], damit
## folgende Effekte derselben Liste damit skalieren können (EffectScaling,
## kind CONSUMED), z. B. „Schaden je verbrauchtem Stapel“.

@export var aura_id: StringName
## Stapel, die entfernt werden (0 = alle, die Aura endet).
@export var stacks := 0
## Nur Auren, die der Wirker angewendet hat.
@export var own_only := false


func _apply(ctx: EffectContext, target: Unit) -> void:
	if target.get_combat() == null:
		return
	var removed := target.get_combat().remove_aura(aura_id, ctx.get_caster() if own_only else null, stacks)
	var key := "aura:%s" % aura_id
	ctx.consumed[key] = float(ctx.consumed.get(key, 0.0)) + removed


func describe() -> String:
	return "Aura %s entfernen" % aura_id
