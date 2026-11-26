class_name HitChanceLogic
extends AuraLogic
## Feste Abwehrchancen gegen Angriffe auf den Träger (seit #53, Schildorkan:
## 8 s lang blockt der Krieger jeden Angriff von vorne). Werte ≥ 0 ersetzen
## die Chance aus dem Wertesystem (Prozent), −1 lässt sie, wie sie ist. Gilt
## nur für körperliche Angriffe (Nahkampf, Fernkampf). Von hinten wird ohnehin
## nicht pariert oder geblockt (HitFormulas.chance_table).

@export var dodge_percent := -1.0
@export var parry_percent := -1.0
@export var block_percent := -1.0


func modify_hit_chances(_instance: AuraInstance, _combat: UnitCombat, raw: Dictionary,
		_attacker: Unit, kind: HitFormulas.AttackKind) -> Dictionary:
	if kind != HitFormulas.AttackKind.MELEE and kind != HitFormulas.AttackKind.RANGED:
		return raw
	var result := raw.duplicate()
	if dodge_percent >= 0.0:
		result[HitFormulas.Outcome.DODGE] = dodge_percent
	if parry_percent >= 0.0:
		result[HitFormulas.Outcome.PARRY] = parry_percent
	if block_percent >= 0.0:
		result[HitFormulas.Outcome.BLOCK] = block_percent
	return result
