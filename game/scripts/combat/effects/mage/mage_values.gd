class_name MageValues
extends RefCounted
## Zahlen für die Magier-Mechaniken (Ticket #22). Alle Effekte und Auren des
## Magiers lesen ihre Zahlen aus faehigkeitswerte.csv, immer mit den
## Veränderungen des Wirkers durch Talente und Auren
## (AbilityData.get_number_for). Diese Hilfe bestimmt, aus welcher Zeile
## gelesen wird:
## 1. eine fest eingetragene Fähigkeit (z. B. die Mechanik „Brand“),
## 2. sonst die Fähigkeit im Kontext (ctx.ability),
## 3. sonst die Fähigkeit, mit der die auslösende Aura angewendet wurde
##    (Auslöser einer Aura haben keine eigene Fähigkeit im Kontext).


## Fähigkeit, deren Zeile gelesen wird (siehe oben) oder null.
static func ability_of(ctx: EffectContext, fixed: AbilityData = null) -> AbilityData:
	if fixed != null:
		return fixed
	if ctx == null:
		return null
	if ctx.ability != null:
		return ctx.ability
	if ctx.aura != null and ctx.aura.ctx != null and ctx.aura.ctx.ability != null:
		return ctx.aura.ctx.ability
	return null


## Zahl (Spalte oder „werte.<schlüssel>“) mit den Veränderungen des Wirkers
## (fehlt der Schlüssel in der Tabelle, ist der Grundwert 0); fallback ohne
## Schlüssel oder ohne Fähigkeit.
static func number(ctx: EffectContext, fixed: AbilityData, key: String, fallback := 0.0) -> float:
	if key == "":
		return fallback
	var ability := ability_of(ctx, fixed)
	if ability == null:
		return fallback
	return ability.get_number_for(ctx.get_caster() if ctx != null else null, key)


## Zahl einer Fähigkeit für einen Wirker (ohne Kontext, z. B. in AuraLogic).
static func number_for(ability: AbilityData, caster: Unit, key: String, fallback := 0.0) -> float:
	if ability == null or key == "":
		return fallback
	return ability.get_number_for(caster, key)


## Stapel einer Aura des Wirkers auf sich selbst (z. B. Rang eines Talents,
## dessen versteckte Aura so viele Stapel hat wie Ränge).
static func own_stacks(unit: Unit, aura_id: StringName) -> int:
	if unit == null or not is_instance_valid(unit) or unit.get_combat() == null or aura_id == &"":
		return 0
	return unit.get_combat().get_stacks(aura_id, unit)
