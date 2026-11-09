class_name MageAuraEffect
extends ApplyAuraEffect
## „Aura anwenden“ mit Zahlen aus der Tabelle (Ticket #22, Klassen-
## Erweiterung nach #32): Stapel, Dauer und Chancen kommen aus
## faehigkeitswerte.csv, inklusive der Veränderungen durch Talente (z. B.
## Schwelbrand: Entzünden legt 3 statt 2 Brand und Brand hält 15 s;
## Klirrende Kälte: Verlangsamungen halten 50 % länger).
##
## Ohne Schlüssel gelten die Felder von ApplyAuraEffect (stacks,
## duration_override bzw. Dauer der Aura).

## Aura per ID, wenn das Feld aura leer ist (vermeidet Kreisverweise zwischen
## Dateien, z. B. Brand-Explosion → Brand → Explosion).
@export var aura_id: StringName
## Zeile für Stapel und Chancen (leer = Fähigkeit im Kontext, siehe MageValues).
@export var values_ability: AbilityData
## Zeile für die Dauer (leer = wie values_ability), z. B. die Mechanik „Brand“.
@export var duration_ability: AbilityData
## Schlüssel der Dauer, z. B. „dauer“ oder „werte.verlangsamung_dauer“.
@export var duration_key := ""
## Schlüssel der Stapel (abgerundet), z. B. „werte.brand_stapel“.
@export var stacks_key := ""
## Schlüssel: Chance in Prozent auf einen Stapel mehr (Funkenschlag).
@export var extra_stack_chance_key := ""
## Stapel = Stapel dieser Aura des Wirkers auf sich selbst (z. B. Rang eines
## Talents: Eisige Adern 1/2/3).
@export var stacks_from_caster_aura: StringName
## Kette: Schlüssel für die Zahl der Sprünge (abgerundet) statt chain_jumps.
@export var jumps_key := ""


func resolve_targets(ctx: EffectContext) -> Array[Array]:
	if target_mode != TargetMode.CHAIN or jumps_key == "":
		return super.resolve_targets(ctx)
	var saved := chain_jumps
	chain_jumps = maxi(0, int(MageValues.number(ctx, values_ability, jumps_key, chain_jumps)))
	var result := super.resolve_targets(ctx)
	chain_jumps = saved
	return result


func get_radius(ctx: EffectContext) -> float:
	if radius_from_ability and values_ability != null:
		var value := MageValues.number(ctx, values_ability, "werte.radius")
		if value > 0.0:
			return value
	return super.get_radius(ctx)


func _apply(ctx: EffectContext, target: Unit) -> void:
	var data := get_aura()
	if data == null or target.get_combat() == null:
		return
	var caster := ctx.get_caster()
	var count := get_stack_count(ctx)
	if extra_stack_chance_key != "":
		var chance := MageValues.number(ctx, values_ability, extra_stack_chance_key)
		if chance > 0.0 and randf() * 100.0 < chance:
			count += 1
	if count <= 0:
		return
	target.get_combat().apply_aura(data, caster, ctx, count, get_duration(ctx))


## Die Aura (Feld aura oder per aura_id).
func get_aura() -> AuraData:
	return aura if aura != null else GameData.get_aura(aura_id)


## Stapel, die dieser Effekt anwendet (ohne Zufall).
func get_stack_count(ctx: EffectContext) -> int:
	if stacks_from_caster_aura != &"":
		return MageValues.own_stacks(ctx.get_caster(), stacks_from_caster_aura)
	if stacks_key != "":
		return int(MageValues.number(ctx, values_ability, stacks_key, stacks))
	return stacks


## Dauer in Sekunden (0 = Dauer der Aura).
func get_duration(ctx: EffectContext) -> float:
	if duration_key == "":
		return duration_override
	var source := duration_ability if duration_ability != null else values_ability
	var value := MageValues.number(ctx, source, duration_key)
	return value if value > 0.0 else duration_override


func describe() -> String:
	var data := get_aura()
	return "Aura %s (Magier)" % (data.display_name if data != null else "?")
