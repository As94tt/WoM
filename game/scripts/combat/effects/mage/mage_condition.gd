class_name MageCondition
extends EffectCondition
## Bedingungen der Magier-Mechaniken (Ticket #22, Klassen-Erweiterung nach
## #32; kind bleibt CUSTOM, die Art steht in mage_kind):
##
## CHANCE_PER_CASTER_STACK – Zufall: value Prozent je Stapel von aura_id des
##                           Wirkers auf sich selbst (Rang eines Talents,
##                           z. B. Kettenreaktion 33/66/100 % mit value 33,34).
## MELEE_RANGE             – Wirker und Ziel stehen höchstens
##                           nahkampf_reichweite (+ value) Meter auseinander
##                           (Nahkampf-Angreifer bei Flammen- und Eisschild).
## TARGET_STACKS_AT_LEAST  – Ziel hat mindestens value eigene Stapel von aura_id.

enum MageKind { CHANCE_PER_CASTER_STACK, MELEE_RANGE, TARGET_STACKS_AT_LEAST }

@export var mage_kind: MageKind = MageKind.CHANCE_PER_CASTER_STACK


func _init() -> void:
	kind = Kind.CUSTOM


func _evaluate(ctx: EffectContext, target: Unit) -> bool:
	var caster := ctx.get_caster()
	match mage_kind:
		MageKind.CHANCE_PER_CASTER_STACK:
			var chance := value * MageValues.own_stacks(caster, aura_id)
			return chance > 0.0 and randf() * 100.0 < chance
		MageKind.MELEE_RANGE:
			if caster == null or target == null or caster == target:
				return false
			return caster.distance_to_unit(target) <= Data.konstante(&"nahkampf_reichweite", 5.0) + value + 0.001
		MageKind.TARGET_STACKS_AT_LEAST:
			if target == null or target.get_combat() == null:
				return false
			return target.get_combat().get_stacks(aura_id, caster) >= int(value)
	return true
