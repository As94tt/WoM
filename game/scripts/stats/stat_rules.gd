class_name StatRules
extends Resource
## Aufbau des Wertesystems (Ticket #19): alle Werte mit Name, Erklärung und
## Formel, in Rechenreihenfolge. Liegt in res://data/stats/stat_rules.tres.
## Die Zahlen stehen in den Tabellen (siehe StatDefinition).

## Abschnitte des Charakterfensters in Anzeigereihenfolge und ihre Titel.
## Wertungen (RATING) und HIDDEN erscheinen nicht als eigene Zeile; die
## Wertungen stehen im Tooltip der Werte, die aus ihnen entstehen.
const SECTION_TITLES := {
	StatDefinition.Category.ATTRIBUTE: "Attribute",
	StatDefinition.Category.OFFENSE: "Offensive",
	StatDefinition.Category.DEFENSE: "Defensive",
	StatDefinition.Category.RESOURCE: "Ressourcen",
}

@export var stats: Array[StatDefinition] = []
## Anzeigenamen der Ressourcen (&"mana" → „Mana“). Das Maximum einer
## Ressource ist der Wert &"max_<id>".
@export var resource_names: Dictionary[StringName, String] = {}

var _by_id: Dictionary[StringName, StatDefinition] = {}


func get_stat(id: StringName) -> StatDefinition:
	if _by_id.size() != stats.size():
		_by_id.clear()
		for definition in stats:
			_by_id[definition.id] = definition
	return _by_id.get(id)


## ID des Maximalwerts einer Ressource, z. B. &"max_mana".
static func max_stat_of(resource_id: StringName) -> StringName:
	return StringName("max_" + String(resource_id))


func get_resource_name(resource_id: StringName) -> String:
	return resource_names.get(resource_id, String(resource_id))
