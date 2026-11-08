class_name AbilityTransformData
extends Resource
## Verwandlung einer Grundfähigkeit durch eine Spezialisierung (Ticket #20):
## „Grundfähigkeit → Variante“. Aktionsleisten speichern weiter die
## Grundfähigkeit; angezeigt und ausgelöst wird die Variante.
##
## Umgesetzt mit dem Effekt- und Aura-System (#32): Der Host legt für jede
## Verwandlung eine Veränderung (AbilityModifierData mit replacement_id) mit
## der Quelle „spec:<id>“ an (PlayerTalents). Talente können die Variante
## danach weiter verändern oder ersetzen (dritter Schritt der Auflösung).

## Grundfähigkeit (z. B. Feuerball aus dem Klassenreiter).
@export var base: AbilityData
## Variante, die statt der Grundfähigkeit gilt (eigener Name, Icon, Tooltip
## und eigene Zeile in faehigkeitswerte.csv).
@export var variant: AbilityData


## Als Veränderung für UnitCombat.add_ability_modifiers (null bei Lücken).
func to_modifier() -> AbilityModifierData:
	if base == null or variant == null:
		return null
	var modifier := AbilityModifierData.new()
	modifier.ability_id = base.id
	modifier.replacement_id = variant.id
	return modifier
