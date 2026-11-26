class_name StrikeEffect
extends DamageEffect
## Schlag mit Erweiterungen (seit #53, entstanden für den Krieger, nutzbar für
## alle Nahkampfklassen). Ohne Einträge verhält er sich wie „Schaden“. Alle
## Zahlen kommen aus faehigkeitswerte.csv (EffectValues: values_ability bzw.
## Fähigkeit im Kontext), inklusive Veränderungen durch Talente.
##
## - Mehrere Schläge (hits_key, z. B. Wilder Hieb: zwei schnelle Schläge).
## - Höchstzahl Ziele aus der Tabelle (max_targets_key, z. B. Wirbelwind;
##   Wirbelnde Klingen erhöht sie).
## - Zusätzliche Bedrohung in Prozent des Schadens (threat_bonus_key, z. B.
##   Schildstoß +50 %), mit dem Bedrohungsfaktor des Wirkers.
## - Zusätzliche kritische Trefferchance nur für diesen Schlag
##   (crit_bonus_key, z. B. Gnadenlos). Wie beim Magier legt der Host dafür
##   einen vorübergehenden Modifikator in den Werteblock und nimmt ihn sofort
##   wieder heraus (nicht übertragen).
## - Zusätzliche Ressource verbrauchen (Hinrichten): Vor den Schlägen werden
##   bis zu werte.<consume_max_key> Punkte von consume_resource abgezogen
##   (einmal je Ausführung, nicht je Ziel); je Punkt steigt der Schaden um
##   werte.<bonus_per_point_key> Prozent. Die Menge steht danach in
##   ctx.consumed[Ressource] und zählt als ausgegeben (Raserei).
## - Kann nicht verfehlen, ausgewichen oder pariert werden (cannot_be_avoided,
##   Überwältigen; Combat.FLAG_NO_AVOID).
## - on_hit_effects: einmal je Ziel, wenn mindestens ein Schlag getroffen hat
##   (Treffer, kritisch, geblockt), Hauptziel = getroffenes Ziel.
## - on_kill_effects: wenn ein Schlag das Ziel tötet (Taktiker: Wut zurück).
##
## Nur auf dem Host (wie jeder Effekt).

## Quelle des vorübergehenden Modifikators für einen Wurf.
const ROLL_SOURCE := &"strike:wurf"
const LANDED := [HitFormulas.Outcome.HIT, HitFormulas.Outcome.CRIT, HitFormulas.Outcome.BLOCK]

## Zahlen aus dieser Fähigkeit statt aus der Fähigkeit im Kontext (z. B. die
## Mechanik „Tiefe Wunde“ für die Ticks der Blutung).
@export var values_ability: AbilityData

@export_group("Schläge und Ziele")
## Schlüssel für die Zahl der Schläge je Ziel (abgerundet, mindestens 1).
@export var hits_key := ""
## Schlüssel für die Höchstzahl Ziele (abgerundet) statt max_targets.
@export var max_targets_key := ""

@export_group("Bedrohung und Kritisch")
## Schlüssel: zusätzliche Bedrohung in Prozent des verursachten Schadens.
@export var threat_bonus_key := ""
## Schlüssel: zusätzliche kritische Trefferchance (Prozentpunkte).
@export var crit_bonus_key := ""

@export_group("Zusätzliche Ressource")
## Ressource, von der zusätzlich verbraucht wird (leer = keine), z. B. &"rage".
@export var consume_resource: StringName = &""
## Schlüssel: höchstens so viele Punkte.
@export var consume_max_key := ""
## Schlüssel: Prozent mehr Schaden je verbrauchtem Punkt.
@export var bonus_per_point_key := ""

@export_group("Treffer")
@export var cannot_be_avoided := false
@export var on_hit_effects: Array[EffectData] = []
@export var on_kill_effects: Array[EffectData] = []


func execute(ctx: EffectContext) -> void:
	var factor := _consume(ctx)
	for entry: Array in resolve_targets(ctx):
		var target: Unit = entry[0]
		if target == null or not is_instance_valid(target) or target.is_dead():
			continue
		var target_ctx := ctx.with_target(target)
		target_ctx.amount_factor = ctx.amount_factor * float(entry[1]) * factor
		if conditions_met(target_ctx, target):
			_strike(target_ctx, target)


## Auch von Flächen genutzt (eigene Zielbestimmung dort aus): ein Ziel.
func _apply(ctx: EffectContext, target: Unit) -> void:
	_strike(ctx, target)


func resolve_targets(ctx: EffectContext) -> Array[Array]:
	if max_targets_key == "":
		return super.resolve_targets(ctx)
	var saved := max_targets
	max_targets = maxi(0, int(_number(ctx, max_targets_key, max_targets)))
	var result := super.resolve_targets(ctx)
	max_targets = saved
	return result


func get_radius(ctx: EffectContext) -> float:
	if radius_from_ability:
		var value := _number(ctx, "werte.radius")
		if value > 0.0:
			return value
	return super.get_radius(ctx)


## Wie AmountEffect, aber mit der Zeile aus EffectValues (feste Zeile bzw.
## Fähigkeit der auslösenden Aura, wenn der Kontext keine hat).
func compute_base(ctx: EffectContext) -> float:
	var ability := EffectValues.ability_of(ctx, values_ability)
	if ctx == null or ability == null or ability == ctx.ability:
		return super.compute_base(ctx)
	var own := ctx.copy()
	own.ability = ability
	return super.compute_base(own)


## Zahl der Schläge je Ziel.
func get_hits(ctx: EffectContext) -> int:
	return maxi(1, int(_number(ctx, hits_key, 1.0))) if hits_key != "" else 1


func describe() -> String:
	return "Schlag (%s)" % Data.schulname(school)


# --- Intern ------------------------------------------------------------------

## Zusätzliche Ressource einmal verbrauchen; gibt den Schadensfaktor zurück.
func _consume(ctx: EffectContext) -> float:
	if consume_resource == &"" or consume_max_key == "":
		return 1.0
	var caster := ctx.get_caster()
	var stats := caster.get_stats() if caster != null else null
	if stats == null:
		return 1.0
	var wanted := minf(stats.get_resource(consume_resource), maxf(0.0, _number(ctx, consume_max_key)))
	if wanted <= 0.0:
		return 1.0
	var taken := -stats.change_resource(consume_resource, -wanted)
	if taken <= 0.0:
		return 1.0
	var key := String(consume_resource)
	ctx.consumed[key] = float(ctx.consumed.get(key, 0.0)) + taken
	if caster.get_combat() != null:
		caster.get_combat().on_resource_spent(consume_resource, taken)
	return 1.0 + taken * _number(ctx, bonus_per_point_key) / 100.0


func _strike(ctx: EffectContext, target: Unit) -> void:
	var caster := ctx.get_caster()
	var crit_bonus := _number(ctx, crit_bonus_key)
	var block: StatBlock = caster.get_stats().block if caster != null and caster.get_stats() != null else null
	var threat_bonus := _number(ctx, threat_bonus_key)
	var flags := Combat.FLAG_PERIODIC if ctx.periodic else 0
	if cannot_be_avoided:
		flags |= Combat.FLAG_NO_AVOID
	var landed := false
	var killed := false
	for index in get_hits(ctx):
		if target.is_dead():
			break
		var stats := target.get_stats()
		var before := stats.health if stats != null else 0.0
		var amount := amount_for(ctx, target)
		if block != null and crit_bonus != 0.0:
			block.add_modifier(StatModifier.create(ROLL_SOURCE, "", &"crit_chance", crit_bonus))
		var result := Combat.roll_damage(caster, target, amount, school, attack_kind_for(ctx), ctx, flags)
		if block != null and crit_bonus != 0.0:
			block.remove_source(ROLL_SOURCE)
		if result == null or not LANDED.has(result.outcome):
			continue
		landed = true
		if threat_bonus != 0.0 and caster != null and caster != target:
			Combat.add_threat(caster, target, result.amount * threat_bonus / 100.0
					* Data.konstante(&"bedrohung_pro_schaden", 1.0))
		# Getötet: Der Schlag nahm das ganze Leben (Übungspuppen füllen sich
		# danach sofort wieder auf, zählen aber wie bei Combat als getötet).
		if before > 0.0 and result.amount >= before - 0.001:
			killed = true
	if landed and not on_hit_effects.is_empty():
		Combat.execute(on_hit_effects, ctx)
	if killed and not on_kill_effects.is_empty():
		Combat.execute(on_kill_effects, ctx)


func _number(ctx: EffectContext, key: String, fallback := 0.0) -> float:
	return EffectValues.number(ctx, values_ability, key, fallback)
