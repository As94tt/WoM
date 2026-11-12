class_name MageLethalGuardLogic
extends AuraLogic
## Schutz vor tödlichem Schaden (Ticket #22, Phönixschild): Solange der
## Träger die Aura required_aura_id hat (Flammenschild) und nicht
## cooldown_aura („Phönixschild erschöpft“), verhindert diese Aura einmal
## tödlichen Schaden; danach bekommt der Träger cooldown_aura (Dauer der
## Aura, z. B. 2 Minuten).
##
## Der Haken für eingehenden Schaden (#32) läuft vor Krit und Minderung
## (Combat.roll_damage). Deshalb rechnet die Logik mit dem schlimmsten Fall:
## Kann der Treffer mit kritischem Schaden des Angreifers mehr nehmen als
## Leben − 1 + Schilde, wird er so begrenzt, dass der Träger mit mindestens
## 1 Leben überlebt, und der Schutz ist verbraucht.

@export var required_aura_id: StringName
@export var cooldown_aura: AuraData


func modify_incoming_damage(_instance: AuraInstance, combat: UnitCombat, amount: float,
		_school: StringName, attacker: Unit) -> float:
	var unit := combat.get_unit()
	var stats := unit.get_stats() if unit != null else null
	if stats == null or amount <= 0.0 or cooldown_aura == null:
		return amount
	if required_aura_id != &"" and combat.get_stacks(required_aura_id) <= 0:
		return amount
	if combat.get_stacks(cooldown_aura.id) > 0:
		return amount
	var crit := Combat.crit_multiplier(attacker)
	var limit := stats.health - 1.0 + combat.get_absorb_total()
	if amount * crit < limit:
		return amount
	combat.apply_aura(cooldown_aura, unit)
	return maxf(0.0, limit / crit)
