class_name MinHealthLogic
extends AuraLogic
## Der Träger kann nicht unter min_health Leben fallen, solange die Aura
## besteht (seit #53, Unbeugsam: 10 s lang nicht unter 1 Leben). Nutzt die
## Untergrenze des Wertesystems (CharacterStats.min_health, nur Host); beim
## Ende gilt wieder die vorherige.

@export var min_health := 1.0


func on_applied(instance: AuraInstance, combat: UnitCombat) -> void:
	var stats := _stats(combat)
	if stats == null:
		return
	instance.custom["previous"] = stats.min_health
	stats.min_health = maxf(stats.min_health, min_health)


func on_removed(instance: AuraInstance, combat: UnitCombat, _reason: int) -> void:
	var stats := _stats(combat)
	if stats != null and instance.custom.has("previous"):
		stats.min_health = float(instance.custom["previous"])


func _stats(combat: UnitCombat) -> CharacterStats:
	var unit := combat.get_unit()
	return unit.get_stats() if unit != null else null
