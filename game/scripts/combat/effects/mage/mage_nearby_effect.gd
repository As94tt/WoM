class_name MageNearbyEffect
extends EffectData
## Weitere Ziele um das Hauptziel (Ticket #22, Klassen-Erweiterung nach #32):
## wählt bis zu werte.<count_key> Einheiten im Umkreis werte.<radius_key>
## um das Hauptziel, die zum Filter passen, und führt effects mit jeder als
## Hauptziel aus.
##
## - include_main: Das Hauptziel zählt mit (sonst nur andere Einheiten).
## - random_pick: zufällig statt der nächsten (Eissplittersalve: Splitter
##   verteilen sich auf Gegner im Umkreis).
## Absoluter Nullpunkt: Frostblitz trifft ein zweites Ziel (werte.zusatzziele).

## Zeile der Zahlen (leer = Fähigkeit im Kontext).
@export var values_ability: AbilityData
## Schlüssel der Anzahl (leer = count).
@export var count_key := ""
@export var count := 1
## Schlüssel des Umkreises (leer = radius).
@export var radius_key := ""
@export var include_main := false
@export var random_pick := false
@export var effects: Array[EffectData] = []


func _apply(ctx: EffectContext, target: Unit) -> void:
	var amount := count
	if count_key != "":
		amount = int(MageValues.number(ctx, values_ability, count_key, count))
	if amount <= 0:
		return
	var range_m := radius
	if radius_key != "":
		var value := MageValues.number(ctx, values_ability, radius_key)
		if value > 0.0:
			range_m = value
	var candidates := _in_radius(ctx, target.global_position, range_m, ctx.get_caster())
	if not include_main:
		candidates.erase(target)
	if candidates.is_empty():
		return
	var chosen: Array[Unit] = []
	if random_pick:
		for i in amount:
			chosen.append(candidates[randi() % candidates.size()])
	else:
		for i in mini(amount, candidates.size()):
			chosen.append(candidates[i])
	for unit in chosen:
		Combat.execute(effects, ctx.with_target(unit))


func describe() -> String:
	return "Weitere Ziele"
