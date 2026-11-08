class_name SpecializationData
extends Resource
## Eine Spezialisierung als Daten (Ticket #20). Jede Klasse listet ihre
## Spezialisierungen in ClassData.specializations; die Datensätze liegen in
## res://data/specializations/, die Bäume in res://data/talents/.
##
## Mit Stufe 10 (spielkonstanten.csv: spezialisierung_ab_stufe) wählt ein
## Charakter eine Spezialisierung. Sie verwandelt sofort Grundfähigkeiten
## (transformations, optional) und schaltet ihren Talentbaum frei.

## Feste ID, unter der Charaktere die Wahl speichern (z. B. &"mage_feuer").
@export var id: StringName
@export var display_name: String
## Beschreibung im Talentfenster; die erste Zeile ist die Kurzbeschreibung
## (auch für gesperrte Spezialisierungen).
@export_multiline var description: String
## Icon; leer = Platzhalter.
@export var icon: Texture2D
## Reihenfolge der Reiter (kleiner = weiter links).
@export var order := 0
## Bevorzugte Werte, nur zur Anzeige (IDs aus stat_rules.tres, z. B.
## &"precision", &"devastation").
@export var preferred_stats: Array[StringName] = []

@export_group("Freischaltung")
## Gesperrt: im Fenster sichtbar, aber nicht wählbar („Noch nicht entdeckt“),
## bis der Charakter sie freigeschaltet hat (vorerst nur über das
## Entwickler-Panel; später eine Klassenquest).
@export var locked := false
## Hinweis, wie man sie freischaltet (nur Anzeige; leer = keiner).
@export var unlock_hint := ""

@export_group("Inhalt")
## Verwandlungen „Grundfähigkeit → Variante“ (optional, leer = keine).
@export var transformations: Array[AbilityTransformData] = []
@export var talent_tree: TalentTreeData
## Klassenspezifische Erweiterung (optional), siehe SpecializationExtension.
@export var extension: SpecializationExtension

const STAT_RULES: StatRules = preload("res://data/stats/stat_rules.tres")


## Erste Zeile der Beschreibung.
func get_short_description() -> String:
	return description.split("\n", false)[0] if description != "" else ""


## Bevorzugte Werte als Text, z. B. „Präzision, Verheerung“.
func get_preferred_stats_text() -> String:
	var names: PackedStringArray = []
	for stat_id in preferred_stats:
		var definition := STAT_RULES.get_stat(stat_id)
		names.append(definition.display_name if definition != null else String(stat_id))
	return ", ".join(names)


## Veränderungen für alle Verwandlungen (Quelle „spec:<id>“).
func get_transform_modifiers() -> Array[AbilityModifierData]:
	var result: Array[AbilityModifierData] = []
	for transform in transformations:
		if transform != null:
			var modifier := transform.to_modifier()
			if modifier != null:
				result.append(modifier)
	return result


## Variante einer Grundfähigkeit in dieser Spezialisierung oder null.
func get_variant_of(base_id: StringName) -> AbilityData:
	for transform in transformations:
		if transform != null and transform.base != null and transform.base.id == base_id:
			return transform.variant
	return null


## Kürzel für das Platzhalter-Icon.
func get_short_name() -> String:
	return display_name.left(2) if display_name != "" else "?"
