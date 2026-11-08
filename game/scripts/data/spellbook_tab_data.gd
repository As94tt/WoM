class_name SpellbookTabData
extends Resource
## Ein Reiter des Zauberbuchs als Daten (Ticket #21): Titel und Fähigkeiten.
## Der Reiter „Allgemein“ liegt in res://data/spellbook/general.tres. Der
## Klassenreiter entsteht aus ClassData (display_name, abilities). Spätere
## Reiter (Unterklassen, Talente) können als weitere SpellbookTabData
## dazukommen, ohne das Zauberbuch zu ändern (PlayerAbilities.get_spellbook_tabs).

## Feste ID des Reiters (z. B. &"general", bei Klassen die Klassen-ID).
@export var id: StringName
## Angezeigter Titel des Reiters.
@export var title: String
## Reihenfolge der Reiter (kleiner = weiter links).
@export var order: int = 0
## Fähigkeiten des Reiters; angezeigt nach benötigter Stufe.
@export var abilities: Array[AbilityData] = []


## Reiter aus einer Klasse (Titel = Klassenname).
static func from_class(class_data: ClassData, tab_order: int) -> SpellbookTabData:
	var tab := SpellbookTabData.new()
	tab.id = class_data.id
	tab.title = class_data.display_name
	tab.order = tab_order
	tab.abilities = class_data.abilities
	return tab


## Fähigkeiten sortiert nach benötigter Stufe, bei gleicher Stufe in der
## Reihenfolge der Daten (stabil).
func get_sorted_abilities() -> Array[AbilityData]:
	var indexed: Array[int] = []
	for i in abilities.size():
		if abilities[i] != null:
			indexed.append(i)
	indexed.sort_custom(func(a: int, b: int) -> bool:
		var la := abilities[a].required_level
		var lb := abilities[b].required_level
		return la < lb if la != lb else a < b)
	var result: Array[AbilityData] = []
	for i in indexed:
		result.append(abilities[i])
	return result
