class_name AmountModifierData
extends Resource
## Prozentualer Modifikator auf Schaden oder Heilung (Ticket #34), als Teil
## einer Aura (AuraData.amount_modifiers). Talente, Haltungen, Siegel und
## Talismane sind Auren und nutzen dasselbe Feld.
##
## Mehrere Modifikatoren derselben Art auf einer Einheit werden addiert
## (+20 % und +10 % → +30 %); Wirker (verursacht) und Ziel (erleidet bzw.
## erhält) werden multipliziert (HitFormulas.percent_factor).

## DAMAGE_DONE    – Schaden, den der Träger verursacht
## DAMAGE_TAKEN   – Schaden, den der Träger erleidet
## HEALING_DONE   – Heilung, die der Träger wirkt
## HEALING_TAKEN  – Heilung, die der Träger erhält („erhaltene Heilung“)
enum Kind { DAMAGE_DONE, DAMAGE_TAKEN, HEALING_DONE, HEALING_TAKEN }

@export var kind: Kind = Kind.DAMAGE_DONE
## Prozent (positiv = mehr, negativ = weniger).
@export var percent := 0.0
## Nur für diese Schadensschulen (IDs aus schadensschulen.csv); leer = alle.
## Bei Heilung ohne Bedeutung.
@export var schools: PackedStringArray = []
## Wert × Stapel der Aura.
@export var scales_with_stacks := true


## Gilt der Modifikator für diese Art und Schule?
func applies_to(p_kind: Kind, school: StringName) -> bool:
	if kind != p_kind:
		return false
	if p_kind == Kind.HEALING_DONE or p_kind == Kind.HEALING_TAKEN or schools.is_empty():
		return true
	return schools.has(String(school))
