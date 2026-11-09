class_name MageCooldownEffect
extends EffectData
## Abklingzeit verkürzen (Ticket #22, Glühende Gedanken: Jede Explosion
## verringert die Abklingzeit von Meteor). Wirkt auf das Ziel des Effekts
## (meist „Wirker selbst“): Dessen laufende Abklingzeit von ability_id sinkt
## um werte.<seconds_key> Sekunden (UnitCaster.host_reduce_cooldown).
## 0 Sekunden (z. B. ohne Talent) = nichts.

@export var ability_id: StringName
## Zeile der Zahlen (leer = Fähigkeit im Kontext).
@export var values_ability: AbilityData
@export var seconds_key := ""


func _apply(ctx: EffectContext, target: Unit) -> void:
	var seconds := MageValues.number(ctx, values_ability, seconds_key)
	var caster_node := target.get_caster_node()
	var ability := GameData.get_ability(ability_id)
	if seconds <= 0.0 or caster_node == null or ability == null:
		return
	caster_node.host_reduce_cooldown(ability, seconds)


func describe() -> String:
	return "Abklingzeit %s verkürzen" % ability_id
