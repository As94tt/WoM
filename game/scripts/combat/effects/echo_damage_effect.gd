class_name EchoDamageEffect
extends EffectData
## Treffer überträgt sich auf weitere Ziele (seit #53, Klingenschwung:
## Einzelzielangriffe treffen ein zweites Ziel). Gedacht für Auslöser
## („Treffer“): Der Betrag des Ereignisses (ctx.event_amount, nach Rüstung)
## × percent Prozent geht als Schaden an bis zu count weitere feindliche
## Einheiten im Umkreis um das Hauptziel (die nächsten zuerst, ohne das
## Hauptziel). Ohne Würfel und ohne Auslöser (Combat.deal_damage mit
## FLAG_NO_PROCS), damit er sich nicht selbst wieder auslöst.

@export var school: StringName = &"physisch"
@export var percent := 100.0
## Schlüssel statt percent (leer = percent), Zeile nach EffectValues.
@export var percent_key := ""
@export var values_ability: AbilityData
@export var count := 1


func _apply(ctx: EffectContext, target: Unit) -> void:
	var caster := ctx.get_caster()
	var share := percent
	if percent_key != "":
		share = EffectValues.number(ctx, values_ability, percent_key, percent)
	var amount := ctx.event_amount * share / 100.0
	if amount <= 0.0 or caster == null:
		return
	var candidates := _in_radius(ctx, target.global_position, get_radius(ctx), caster)
	candidates.erase(target)
	for index in mini(count, candidates.size()):
		Combat.deal_damage(caster, candidates[index], amount, school, ctx,
				Combat.FLAG_NO_PROCS | Combat.FLAG_NO_REDIRECT)


func describe() -> String:
	return "Treffer überträgt sich (%d)" % count
