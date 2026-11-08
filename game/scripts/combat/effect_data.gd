class_name EffectData
extends Resource
## Ein Effekt als Daten (Ticket #32): Baustein mit Art, Zielbestimmung,
## Bedingungen und Skalierung. Die Art ist die Unterklasse
## (scripts/combat/effects/*.gd); diese Basis kümmert sich um die Ziele.
## Effekte liegen als Unterressourcen in Fähigkeiten (AbilityData.effects),
## Auren (Ticks, Anwenden, Auslöser) und anderen Effekten (Fläche, Projektil).
##
## Ausgeführt wird nur auf dem Host (Combat.execute). Ablauf je Effekt:
## resolve_targets() → je Ziel Filter, Bedingungen → _apply(ctx, ziel).
##
## Eigene Effektarten (Klassen-Mechaniken): Unterklasse anlegen und _apply()
## überschreiben; für besondere Zielwahl zusätzlich resolve_targets().

## Zielbestimmung.
## TARGET         – das Hauptziel (ctx.target)
## SELF           – der Wirker
## AROUND_CASTER  – alle Einheiten im Umkreis radius um den Wirker
## AROUND_TARGET  – im Umkreis um das Hauptziel
## AROUND_POINT   – im Umkreis um den Punkt (ctx.point, sonst das Ziel)
## CONE           – Kegel vor dem Wirker (Länge radius, Winkel cone_angle)
## LINE           – Linie vor dem Wirker (Länge radius, Breite line_width)
## CHAIN          – Hauptziel, dann Sprünge zu weiteren Zielen (chain_*)
## PARTY          – Gruppenmitglieder im Umkreis radius um den Wirker
##                  (bis es Gruppen gibt: alle Spieler, die dem Wirker
##                  freundlich gesinnt sind, inklusive Wirker)
enum TargetMode { TARGET, SELF, AROUND_CASTER, AROUND_TARGET, AROUND_POINT, CONE, LINE, CHAIN, PARTY }
## Filter aus Sicht des Wirkers.
enum Filter { ANY, FRIENDLY, HOSTILE }

@export_group("Ziele")
@export var target_mode: TargetMode = TargetMode.TARGET
@export var filter: Filter = Filter.ANY
## Höchstzahl Ziele (0 = unbegrenzt). Bei Flächen: die nächsten zuerst.
@export var max_targets := 0
## Umkreis, Kegel- bzw. Linienlänge, Reichweite eines Kettensprungs (Meter,
## von Rand zu Rand).
@export var radius := 0.0
## Öffnungswinkel des Kegels in Grad.
@export var cone_angle := 90.0
## Breite der Linie in Metern.
@export var line_width := 2.0
## Umkreis um den Wirker: Wirker selbst zählt mit.
@export var include_caster := false
## Kette: Anzahl Sprünge nach dem ersten Ziel.
@export var chain_jumps := 0
## Kette: Abschwächung je Sprung in Prozent (25 = jeder Sprung 25 % weniger).
@export var chain_falloff_percent := 0.0

@export_group("Bedingungen und Skalierung")
## Alle müssen erfüllt sein, sonst wirkt der Effekt auf dieses Ziel nicht.
@export var conditions: Array[EffectCondition] = []
## Faktoren auf Schaden, Heilung, Absorption und Ressourcenmengen.
@export var scaling: Array[EffectScaling] = []


## Host: Effekt auf alle Ziele anwenden.
func execute(ctx: EffectContext) -> void:
	for entry: Array in resolve_targets(ctx):
		var target: Unit = entry[0]
		var target_ctx := ctx.with_target(target)
		target_ctx.amount_factor = ctx.amount_factor * float(entry[1])
		apply_checked(target_ctx, target)


## Bedingungen prüfen und anwenden (auch von Flächen genutzt, die ihre Ziele
## selbst bestimmen).
func apply_checked(ctx: EffectContext, target: Unit) -> void:
	if target == null or not is_instance_valid(target) or target.is_dead():
		return
	if conditions_met(ctx, target):
		_apply(ctx, target)


## Ziele als Liste von [Unit, Faktor]. Faktor < 1 bei Kettensprüngen.
func resolve_targets(ctx: EffectContext) -> Array[Array]:
	var caster := ctx.get_caster()
	var result: Array[Array] = []
	var units: Array[Unit] = []
	match target_mode:
		TargetMode.TARGET:
			if ctx.target != null and is_instance_valid(ctx.target) and passes_filter(caster, ctx.target):
				units.append(ctx.target)
		TargetMode.SELF:
			if caster != null:
				units.append(caster)
		TargetMode.AROUND_CASTER:
			if caster != null:
				units = _in_radius(ctx, caster.global_position, radius, caster)
		TargetMode.AROUND_TARGET:
			if ctx.target != null and is_instance_valid(ctx.target):
				units = _in_radius(ctx, ctx.target.global_position, radius, caster)
		TargetMode.AROUND_POINT:
			units = _in_radius(ctx, ctx.get_point(), radius, caster)
		TargetMode.CONE, TargetMode.LINE:
			if caster != null:
				units = _in_front(ctx, caster)
		TargetMode.CHAIN:
			return _chain(ctx, caster)
		TargetMode.PARTY:
			if caster != null:
				for unit in _in_radius(ctx, caster.global_position, radius, caster, true):
					if unit.is_player_unit() and caster.get_reaction_to(unit) == Unit.Reaction.FRIENDLY:
						units.append(unit)
	if max_targets > 0 and units.size() > max_targets:
		units.resize(max_targets)
	for unit in units:
		result.append([unit, 1.0])
	return result


## true, wenn target für den Filter (aus Sicht des Wirkers) passt.
func passes_filter(caster: Unit, target: Unit) -> bool:
	match filter:
		Filter.HOSTILE:
			return caster != null and Combat.is_hostile(caster, target)
		Filter.FRIENDLY:
			return caster == null or caster.get_reaction_to(target) == Unit.Reaction.FRIENDLY
	return true


func conditions_met(ctx: EffectContext, target: Unit) -> bool:
	for condition in conditions:
		if condition != null and not condition.is_met(ctx, target):
			return false
	return true


## Betrag mit Kontextfaktor (Kette, Stapel) und Skalierungen.
func scale_amount(amount: float, ctx: EffectContext, target: Unit) -> float:
	amount *= ctx.amount_factor
	for entry in scaling:
		if entry != null:
			amount *= entry.get_factor(ctx, target)
	return amount


## Fester Betrag zum Zeitpunkt des Anwendens einer Aura (Schaden und Heilung
## über Zeit). NAN = dieser Effekt hat keinen.
func compute_snapshot(_ctx: EffectContext) -> float:
	return NAN


## Kurzbeschreibung für das Entwickler-Panel.
func describe() -> String:
	return get_script().get_global_name() if get_script() != null else "Effekt"


## Die eigentliche Wirkung auf ein Ziel. Unterklassen überschreiben das.
func _apply(_ctx: EffectContext, _target: Unit) -> void:
	pass


# --- Intern ------------------------------------------------------------------

## Lebende Einheiten im Umkreis (Rand zu Rand), Filter angewendet, nach
## Entfernung sortiert.
func _in_radius(ctx: EffectContext, center: Vector3, range_m: float, caster: Unit,
		force_caster := false) -> Array[Unit]:
	var tree := _tree(ctx)
	var result: Array[Unit] = []
	if tree == null:
		return result
	var distances := {}
	for unit in Unit.all_units(tree):
		if unit.is_dead():
			continue
		if unit == caster and not (include_caster or force_caster):
			continue
		var offset := unit.global_position - center
		var distance := maxf(0.0, Vector2(offset.x, offset.z).length() - unit.get_body_radius())
		if distance > range_m or absf(offset.y) > range_m + unit.get_body_height():
			continue
		if not passes_filter(caster, unit) and not (unit == caster and (include_caster or force_caster)):
			continue
		distances[unit] = distance
		result.append(unit)
	result.sort_custom(func(a: Unit, b: Unit) -> bool: return distances[a] < distances[b])
	return result


## Kegel bzw. Linie vor dem Wirker.
func _in_front(ctx: EffectContext, caster: Unit) -> Array[Unit]:
	var result: Array[Unit] = []
	var forward := caster.get_facing()
	var right := Vector3(-forward.z, 0.0, forward.x)
	for unit in _in_radius(ctx, caster.global_position, radius, caster):
		var offset := unit.global_position - caster.global_position
		offset.y = 0.0
		if target_mode == TargetMode.CONE:
			if offset.length() > 0.01 and rad_to_deg(forward.angle_to(offset.normalized())) > cone_angle / 2.0:
				continue
		else:
			var along := offset.dot(forward)
			var side := absf(offset.dot(right)) - unit.get_body_radius()
			if along < -unit.get_body_radius() or side > line_width / 2.0:
				continue
		result.append(unit)
	return result


## Kette: vom Hauptziel aus jeweils zur nächsten noch nicht getroffenen
## Einheit innerhalb radius, die zum Filter passt.
func _chain(ctx: EffectContext, caster: Unit) -> Array[Array]:
	var result: Array[Array] = []
	var current := ctx.target
	if current == null or not is_instance_valid(current) or not passes_filter(caster, current):
		return result
	var hit: Array[Unit] = [current]
	var factor := 1.0
	result.append([current, factor])
	for jump in chain_jumps:
		var best: Unit = null
		var best_distance := INF
		for unit in Unit.all_units(_tree(ctx)):
			if hit.has(unit) or unit.is_dead() or unit == caster or not passes_filter(caster, unit):
				continue
			var distance := current.distance_to_unit(unit)
			if distance <= radius and distance < best_distance:
				best = unit
				best_distance = distance
		if best == null:
			break
		factor *= maxf(0.0, 1.0 - chain_falloff_percent / 100.0)
		hit.append(best)
		result.append([best, factor])
		current = best
		if max_targets > 0 and result.size() >= max_targets:
			break
	return result


func _tree(ctx: EffectContext) -> SceneTree:
	for unit: Unit in [ctx.get_caster(), ctx.target]:
		if unit != null and is_instance_valid(unit) and unit.is_inside_tree():
			return unit.get_tree()
	return Engine.get_main_loop() as SceneTree
