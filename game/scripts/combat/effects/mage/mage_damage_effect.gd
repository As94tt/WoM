class_name MageDamageEffect
extends DamageEffect
## Schaden mit den Erweiterungen der Magier-Mechaniken (Ticket #22, Klassen-
## Erweiterung nach #32). Alles Zusätzliche ist optional; ohne Einträge
## verhält sich der Effekt wie „Schaden“. Zahlen kommen aus
## faehigkeitswerte.csv (MageValues), Talente verändern sie über „Fähigkeit
## verändern“.
##
## - values_ability: Zahlen aus einer festen Zeile statt aus der Fähigkeit im
##   Kontext (z. B. die Mechanik „Brand“ für Ticks und Explosion).
## - Stapel verbrauchen (Donnerschlag, Sonnenzorn): Vor dem Treffer werden
##   die eigenen Stapel einer Aura am Ziel entfernt; je Stapel mehr Schaden.
##   Ab full_stacks verbrauchten Stapeln laufen full_effects.
## - Kette mit Zahlen aus der Tabelle (Sprünge, Schaden der Sprungziele in
##   Prozent) und Effekte auf jedes Sprungziel.
## - Kritisch: zusätzliche Trefferchance je Stapel einer Aura am Ziel
##   (Verbrennung), zusätzlicher kritischer Schaden (Inferno), Effekte nach
##   einem kritischen Treffer (Hitzewelle). Die Zuschläge gelten nur für
##   diesen einen Wurf: Der Host legt sie als vorübergehende Modifikatoren
##   in den Werteblock des Wirkers und nimmt sie sofort wieder heraus (nicht
##   übertragen).
##
## Nur auf dem Host (wie jeder Effekt).

## Quelle der vorübergehenden Modifikatoren für einen Wurf.
const ROLL_SOURCE := &"mage:wurf"

## Zahlen aus dieser Fähigkeit statt aus der Fähigkeit im Kontext.
@export var values_ability: AbilityData

@export_group("Stapel verbrauchen")
## Aura, deren eigene Stapel am Ziel vor dem Treffer verbraucht werden.
@export var consume_aura_id: StringName
## Schlüssel: Prozent mehr Schaden je verbrauchtem Stapel.
@export var bonus_per_stack_key := ""
## Ab so vielen verbrauchten Stapeln laufen full_effects (0 = nie).
@export var full_stacks := 0
@export var full_effects: Array[EffectData] = []

@export_group("Kette")
## Schlüssel für die Zahl der Sprünge (abgerundet) statt chain_jumps.
@export var jumps_key := ""
## Schlüssel: Schaden der Sprungziele in Prozent (statt chain_falloff_percent).
@export var jump_percent_key := ""
## Effekte auf jedes Sprungziel nach dessen Treffer.
@export var jump_effects: Array[EffectData] = []

@export_group("Kritisch")
## Schlüssel: zusätzliche kritische Trefferchance (Prozentpunkte) je eigenem
## Stapel von crit_stack_aura_id am Ziel.
@export var crit_per_stack_key := ""
@export var crit_stack_aura_id: StringName
## Schlüssel: zusätzlicher kritischer Schaden (Prozentpunkte, 200 → 250).
@export var crit_damage_key := ""
## Effekte nach einem kritischen Treffer (Hauptziel = getroffenes Ziel).
@export var on_crit_effects: Array[EffectData] = []


func execute(ctx: EffectContext) -> void:
	var entries := resolve_targets(ctx)
	for index in entries.size():
		var target: Unit = entries[index][0]
		if target == null or not is_instance_valid(target) or target.is_dead():
			continue
		var target_ctx := ctx.with_target(target)
		target_ctx.amount_factor = ctx.amount_factor * float(entries[index][1])
		if conditions_met(target_ctx, target):
			_hit(target_ctx, target, index > 0)


func resolve_targets(ctx: EffectContext) -> Array[Array]:
	if target_mode != TargetMode.CHAIN or jumps_key == "":
		return _with_jump_percent(ctx, super.resolve_targets(ctx))
	var saved := chain_jumps
	chain_jumps = maxi(0, int(MageValues.number(ctx, values_ability, jumps_key, chain_jumps)))
	var result := super.resolve_targets(ctx)
	chain_jumps = saved
	return _with_jump_percent(ctx, result)


func get_radius(ctx: EffectContext) -> float:
	if radius_from_ability:
		var value := MageValues.number(ctx, values_ability, "werte.radius")
		if value > 0.0:
			return value
	return super.get_radius(ctx)


## Wie AmountEffect, aber mit der Zeile aus MageValues (feste Zeile bzw.
## Fähigkeit der auslösenden Aura, wenn der Kontext keine hat).
func compute_base(ctx: EffectContext) -> float:
	var ability := MageValues.ability_of(ctx, values_ability)
	if ctx == null or ability == null or ability == ctx.ability:
		return super.compute_base(ctx)
	var own := ctx.copy()
	own.ability = ability
	return super.compute_base(own)


func _apply(ctx: EffectContext, target: Unit) -> void:
	_hit(ctx, target, false)


func describe() -> String:
	return "Magier-Schaden (%s)" % Data.schulname(school)


func _hit(ctx: EffectContext, target: Unit, is_jump: bool) -> void:
	var caster := ctx.get_caster()
	var amount := amount_for(ctx, target)
	var consumed := 0
	if consume_aura_id != &"" and target.get_combat() != null:
		consumed = target.get_combat().remove_aura(consume_aura_id, caster)
		var key := "aura:%s" % consume_aura_id
		ctx.consumed[key] = float(ctx.consumed.get(key, 0.0)) + consumed
		amount *= 1.0 + consumed * _number(ctx, bonus_per_stack_key) / 100.0
	var crit_bonus := 0.0
	if crit_per_stack_key != "" and crit_stack_aura_id != &"" and target.get_combat() != null:
		crit_bonus = _number(ctx, crit_per_stack_key) * target.get_combat().get_stacks(crit_stack_aura_id, caster)
	var crit_damage_bonus := _number(ctx, crit_damage_key)
	var block: StatBlock = caster.get_stats().block if caster != null and caster.get_stats() != null else null
	var temporary := block != null and (crit_bonus != 0.0 or crit_damage_bonus != 0.0)
	if temporary:
		if crit_bonus != 0.0:
			block.add_modifier(StatModifier.create(ROLL_SOURCE, "", &"crit_chance", crit_bonus))
		if crit_damage_bonus != 0.0:
			block.add_modifier(StatModifier.create(ROLL_SOURCE, "", &"crit_damage", crit_damage_bonus))
	var flags := Combat.FLAG_PERIODIC if ctx.periodic else 0
	var result := Combat.roll_damage(caster, target, amount, school, attack_kind_for(ctx), ctx, flags)
	if temporary:
		block.remove_source(ROLL_SOURCE)
	if result != null and result.is_crit() and not on_crit_effects.is_empty():
		Combat.execute(on_crit_effects, ctx)
	if full_stacks > 0 and consumed >= full_stacks:
		Combat.execute(full_effects, ctx)
	if is_jump:
		Combat.execute(jump_effects, ctx)


func _number(ctx: EffectContext, key: String) -> float:
	return MageValues.number(ctx, values_ability, key)


## Sprungziele mit festem Prozentsatz statt Abschwächung je Sprung.
func _with_jump_percent(ctx: EffectContext, entries: Array[Array]) -> Array[Array]:
	if jump_percent_key == "" or entries.size() <= 1:
		return entries
	var factor := maxf(0.0, _number(ctx, jump_percent_key) / 100.0)
	for index in range(1, entries.size()):
		entries[index][1] = factor
	return entries
