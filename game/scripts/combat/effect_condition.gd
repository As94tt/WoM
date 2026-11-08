class_name EffectCondition
extends Resource
## Bedingung eines Effekts (Ticket #32), z. B. „nur wenn das Ziel verlangsamt
## ist“, „nur von hinten“, „Ziel unter 35 % Leben“. Ist eine Bedingung nicht
## erfüllt, wirkt der Effekt auf dieses Ziel nicht.
##
## Eigene Bedingungen (Klassen): Unterklasse anlegen, kind = CUSTOM lassen und
## _evaluate() überschreiben.

enum Kind {
	TARGET_HAS_AURA,          ## Ziel hat Aura aura_id
	CASTER_HAS_AURA,          ## Wirker hat Aura aura_id
	TARGET_HAS_STATE,         ## Ziel hat einen der Zustände in states
	CASTER_HAS_STATE,         ## Wirker hat einen der Zustände in states
	TARGET_HEALTH_BELOW,      ## Leben des Ziels unter value Prozent
	TARGET_HEALTH_ABOVE,      ## Leben des Ziels über value Prozent
	CASTER_HEALTH_BELOW,      ## Leben des Wirkers unter value Prozent
	CASTER_BEHIND_TARGET,     ## Wirker steht hinter dem Ziel
	CASTER_IN_FRONT_OF_TARGET,## Wirker steht vor dem Ziel
	TARGET_IN_COMBAT,         ## Ziel ist im Kampf
	CHANCE,                   ## Zufall: value Prozent
	CUSTOM,                   ## eigene Logik (Unterklasse)
}

@export var kind: Kind = Kind.TARGET_HAS_AURA
## Aura für *_HAS_AURA.
@export var aura_id: StringName
## Nur Auren zählen, die der Wirker selbst angewendet hat.
@export var own_aura_only := false
## Zustände für *_HAS_STATE (einer davon genügt).
@export_flags("Betäubt", "Festgehalten", "Verlangsamt", "Still", "Umgeworfen", "Getarnt", "Unverwundbar") var states := 0
## Prozentwert für Leben und Zufall.
@export var value := 0.0
## Ergebnis umkehren („nicht …“).
@export var negate := false


func is_met(ctx: EffectContext, target: Unit) -> bool:
	return _evaluate(ctx, target) != negate


func _evaluate(ctx: EffectContext, target: Unit) -> bool:
	var caster := ctx.get_caster()
	match kind:
		Kind.TARGET_HAS_AURA:
			return _has_aura(target, caster)
		Kind.CASTER_HAS_AURA:
			return _has_aura(caster, caster)
		Kind.TARGET_HAS_STATE:
			return target != null and target.get_combat() != null and target.get_combat().get_states() & states != 0
		Kind.CASTER_HAS_STATE:
			return caster != null and caster.get_combat() != null and caster.get_combat().get_states() & states != 0
		Kind.TARGET_HEALTH_BELOW:
			return _health_percent(target) < value
		Kind.TARGET_HEALTH_ABOVE:
			return _health_percent(target) > value
		Kind.CASTER_HEALTH_BELOW:
			return _health_percent(caster) < value
		Kind.CASTER_BEHIND_TARGET:
			return caster != null and target != null and caster.is_behind(target)
		Kind.CASTER_IN_FRONT_OF_TARGET:
			return caster != null and target != null and target.is_in_front(caster)
		Kind.TARGET_IN_COMBAT:
			return target != null and target.get_stats() != null and target.get_stats().is_in_combat()
		Kind.CHANCE:
			return randf() * 100.0 < value
	return true


func _has_aura(unit: Unit, caster: Unit) -> bool:
	if unit == null or unit.get_combat() == null:
		return false
	return unit.get_combat().get_stacks(aura_id, caster if own_aura_only else null) > 0


static func _health_percent(unit: Unit) -> float:
	if unit == null or unit.get_stats() == null or unit.get_stats().max_health <= 0.0:
		return 0.0
	return 100.0 * unit.get_stats().health / unit.get_stats().max_health
