class_name SpreadAuraEffect
extends EffectData
## Aura verbreiten (seit #53, Blutige Ernte: Hinrichten verbreitet alle Wunden
## auf 2 nahe Ziele). Die eigenen Stapel von aura_id am Hauptziel werden auf
## bis zu werte.<count_key> weitere Einheiten im Umkreis werte.<radius_key>
## um das Hauptziel übertragen (die nächsten zuerst, Filter des Effekts),
## mit derselben Zahl an Stapeln. Das Hauptziel behält seine.

@export var aura_id: StringName
## Zeile der Zahlen (leer = Fähigkeit im Kontext).
@export var values_ability: AbilityData
## Schlüssel der Anzahl (leer = count).
@export var count_key := ""
@export var count := 1
## Schlüssel des Umkreises (leer = radius).
@export var radius_key := ""


func _apply(ctx: EffectContext, target: Unit) -> void:
	var caster := ctx.get_caster()
	var data := GameData.get_aura(aura_id)
	if data == null or target.get_combat() == null:
		return
	var stacks := target.get_combat().get_stacks(aura_id, caster)
	if stacks <= 0:
		return
	var amount := count
	if count_key != "":
		amount = int(EffectValues.number(ctx, values_ability, count_key, count))
	var range_m := radius
	if radius_key != "":
		var value := EffectValues.number(ctx, values_ability, radius_key)
		if value > 0.0:
			range_m = value
	var candidates := _in_radius(ctx, target.global_position, range_m, caster)
	candidates.erase(target)
	for index in mini(amount, candidates.size()):
		var unit := candidates[index]
		if unit.get_combat() != null:
			unit.get_combat().apply_aura(data, caster, ctx, stacks)


func describe() -> String:
	return "Aura %s verbreiten" % aura_id
