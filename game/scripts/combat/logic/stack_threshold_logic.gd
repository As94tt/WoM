class_name StackThresholdLogic
extends AuraLogic
## Volle Stapel lösen eine Aura beim Träger aus (seit #53, Berserker: Bei 5
## Raserei wird Blutrausch ausgelöst). Erreicht die Aura threshold Stapel
## (0 = ihre Höchstzahl, AuraData.get_max_stacks) und hat der Träger
## result_aura noch nicht, bekommt er sie mit der Dauer werte.<duration_key>
## aus values_ability (mit den Veränderungen des Trägers, z. B. Blinde Wut).
## Solange result_aura besteht, löst die Schwelle nicht erneut aus (sonst
## würde jeder weitere Stapel sie verlängern).
##
## Was danach passiert (z. B. „danach fallen alle Stapel ab“), steht in den
## Daten von result_aura (Auslöser „Ablauf der Aura“ → Aura entfernen).

@export var result_aura: AuraData
## Ab so vielen Stapeln (0 = Höchstzahl der Aura).
@export var threshold := 0
@export var values_ability: AbilityData
@export var duration_key := "dauer"


func on_applied(instance: AuraInstance, combat: UnitCombat) -> void:
	_check(instance, combat)


func on_refreshed(instance: AuraInstance, combat: UnitCombat) -> void:
	_check(instance, combat)


func _check(instance: AuraInstance, combat: UnitCombat) -> void:
	if result_aura == null:
		return
	var unit := combat.get_unit()
	if unit == null or unit.is_dead():
		return
	var caster := instance.get_caster(combat.get_tree())
	var needed := threshold if threshold > 0 else instance.data.get_max_stacks(caster)
	if instance.stacks < needed or combat.get_stacks(result_aura.id) > 0:
		return
	var duration := EffectValues.number_for(values_ability, unit, duration_key)
	combat.apply_aura(result_aura, unit, null, 1, maxf(0.0, duration))
