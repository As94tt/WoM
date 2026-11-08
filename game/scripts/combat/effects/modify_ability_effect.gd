class_name ModifyAbilityEffect
extends EffectData
## Effekt „Fähigkeit verändern“ (Ticket #32): ersetzt oder verändert
## Fähigkeiten des Ziels (für Talente, Spezialisierungen, Siegel, Talismane).
##
## Steht der Effekt in den „Beim Anwenden“-Effekten einer Aura, gilt die
## Veränderung, solange die Aura besteht (Quelle = die Aura). Sonst gilt sie
## mit der Quelle des Kontexts (z. B. &"talent:feuerkraft"), bis
## UnitCombat.remove_ability_modifiers(quelle) sie entfernt. Talente (#20)
## können beides nutzen: eine dauerhafte Aura mit diesem Effekt oder den
## Effekt direkt mit eigener Quelle.

@export var modifiers: Array[AbilityModifierData] = []


func _apply(ctx: EffectContext, target: Unit) -> void:
	if target.get_combat() == null:
		return
	var source := ctx.aura.source_key() if ctx.aura != null else ctx.source_id
	target.get_combat().add_ability_modifiers(source, modifiers, ctx.source_name)


func describe() -> String:
	return "Fähigkeit verändern (%d)" % modifiers.size()
