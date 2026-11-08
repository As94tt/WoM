class_name EffectScaling
extends Resource
## Skalierung eines Effekts (Ticket #32), z. B. „pro Stapel von Aura X“, „pro
## verbrauchtem Combopunkt“, „pro verbrauchter Wut“. Ergibt einen Faktor auf
## Schaden, Heilung, Absorption bzw. Ressourcenmenge.
##
## Verbrauchtes steht in ctx.consumed: Fähigkeiten (#33) tragen ihre Kosten
## ein (z. B. "rage", "combo_points"); „Aura entfernen“ trägt verbrauchte
## Stapel als "aura:<id>" ein, „Ressource ändern“ entzogene Mengen unter der
## Ressourcen-ID.
##
## Eigene Skalierungen (Klassen): Unterklasse anlegen, kind = CUSTOM lassen
## und _count() überschreiben.

enum Kind {
	AURA_STACKS_ON_TARGET,   ## Stapel von aura_id auf dem Ziel
	AURA_STACKS_ON_CASTER,   ## Stapel von aura_id auf dem Wirker
	CONSUMED,                ## ctx.consumed[consumed_key]
	TARGET_MISSING_HEALTH,   ## fehlendes Leben des Ziels in Prozent
	CUSTOM,                  ## eigene Logik (Unterklasse)
}
## MULTIPLY: Betrag × Anzahl (0 Stapel = 0).
## PERCENT_PER_UNIT: Betrag × (1 + Anzahl × percent_per_unit / 100).
enum Mode { MULTIPLY, PERCENT_PER_UNIT }

@export var kind: Kind = Kind.AURA_STACKS_ON_TARGET
@export var mode: Mode = Mode.MULTIPLY
@export var aura_id: StringName
## Nur Stapel zählen, die der Wirker angewendet hat.
@export var own_aura_only := true
## Schlüssel in ctx.consumed, z. B. "rage", "combo_points", "aura:test_stapel".
@export var consumed_key := ""
@export var percent_per_unit := 0.0


func get_factor(ctx: EffectContext, target: Unit) -> float:
	var count := _count(ctx, target)
	if mode == Mode.MULTIPLY:
		return count
	return 1.0 + count * percent_per_unit / 100.0


func _count(ctx: EffectContext, target: Unit) -> float:
	var caster := ctx.get_caster()
	match kind:
		Kind.AURA_STACKS_ON_TARGET:
			return _stacks(target, caster)
		Kind.AURA_STACKS_ON_CASTER:
			return _stacks(caster, caster)
		Kind.CONSUMED:
			return float(ctx.consumed.get(consumed_key, 0.0))
		Kind.TARGET_MISSING_HEALTH:
			return 100.0 - EffectCondition._health_percent(target)
	return 1.0


func _stacks(unit: Unit, caster: Unit) -> float:
	if unit == null or unit.get_combat() == null:
		return 0.0
	return float(unit.get_combat().get_stacks(aura_id, caster if own_aura_only else null))
