class_name LevelUpSummary
extends RefCounted
## Was ein Aufstieg von previous_level auf level bringt (Ticket #27), für die
## Aufstiegsmeldung (LevelUpBanner) und Tests. Alles kommt aus Daten, nichts
## ist für eine Stufe einzeln programmiert:
## - gestiegene Grundwerte: Attribute (StatRules, Abschnitt „Attribute“ mit
##   Spalte in klassenwachstum.csv), Differenz der Klassenwerte beider Stufen;
##   Volksboni ändern sich nicht und zählen deshalb nicht mit,
## - neue Fähigkeiten: Fähigkeiten der Figur, deren required_level dazwischen
##   liegt (ohne Testfähigkeiten und Fähigkeiten aus Talenten),
## - Talentpunkte: TalentRules (talentpunkt_ab_stufe, talentpunkte_je_stufe),
## - Spezialisierung wählbar: spezialisierung_ab_stufe überschritten und die
##   Klasse hat Spezialisierungen,
## - weitere Freischaltungen: stufenfreischaltungen.csv (z. B. später ein
##   Reittier), abfragbar mit has_unlock().
## Mehrere Stufen auf einmal werden zusammengefasst.

const UNLOCK_TABLE := "stufenfreischaltungen"

var previous_level := 1
var level := 1
## Gestiegene Attribute: [{"name": „Ausdauer“, "value": 3}, …], größte zuerst.
var stat_gains: Array[Dictionary] = []
## Neu erlernte Fähigkeiten, nach benötigter Stufe sortiert.
var abilities: Array[AbilityData] = []
## Neue Talentpunkte (ohne Bonuspunkte).
var talent_points := 0
## Die Wahl der Spezialisierung ist mit diesem Aufstieg möglich geworden.
var spec_unlocked := false
## Weitere Freischaltungen: [{"id", "text", "window" (leer = keins)}, …].
var extras: Array[Dictionary] = []


## Zusammenfassung für eine Klasse. all_abilities: alle Fähigkeiten der Figur
## (PlayerAbilities.get_all_abilities); talent_abilities werden übersprungen.
static func build(class_id: StringName, p_previous: int, p_level: int,
		all_abilities: Array[AbilityData] = [], talent_abilities: Array[AbilityData] = []) -> LevelUpSummary:
	var summary := LevelUpSummary.new()
	summary.previous_level = p_previous
	summary.level = p_level
	if p_level <= p_previous:
		return summary
	summary.stat_gains = stat_gains_between(class_id, p_previous, p_level)
	for ability in all_abilities:
		if ability == null or ability.dev_only or talent_abilities.has(ability):
			continue
		if ability.required_level > p_previous and ability.required_level <= p_level \
				and not summary.abilities.has(ability):
			summary.abilities.append(ability)
	summary.abilities.sort_custom(func(a: AbilityData, b: AbilityData) -> bool:
		return a.required_level < b.required_level)
	summary.talent_points = TalentRules.total_points(p_level) - TalentRules.total_points(p_previous)
	var class_data := GameData.get_class_data(class_id)
	var needed := TalentRules.spec_level()
	summary.spec_unlocked = p_previous < needed and p_level >= needed and class_data != null \
			and not class_data.get_specializations().is_empty()
	summary.extras = extras_between(class_id, p_previous, p_level, Data.rows(UNLOCK_TABLE))
	return summary


## Attribute, die zwischen den Stufen nach klassenwachstum.csv steigen.
static func stat_gains_between(class_id: StringName, p_previous: int, p_level: int) -> Array[Dictionary]:
	var before := Data.klassenwerte(class_id, p_previous)
	var after := Data.klassenwerte(class_id, p_level)
	var definitions: Array[StatDefinition] = []
	for definition in CharacterStats.RULES.stats:
		if definition.category == StatDefinition.Category.ATTRIBUTE and definition.level_column != "":
			definitions.append(definition)
	definitions.sort_custom(func(a: StatDefinition, b: StatDefinition) -> bool:
		return a.display_order < b.display_order)
	var result: Array[Dictionary] = []
	for definition in definitions:
		var gain := int(after.get(definition.level_column, 0)) - int(before.get(definition.level_column, 0))
		if gain != 0:
			result.append({"name": definition.display_name, "value": gain})
	# Stabil nach Zuwachs sortieren (größter zuerst, sonst Anzeigereihenfolge).
	var order := result.duplicate()
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["value"]) != int(b["value"]):
			return int(a["value"]) > int(b["value"])
		return order.find(a) < order.find(b))
	return result


## Zeilen aus stufenfreischaltungen.csv, die zwischen den Stufen frei werden
## (Klasse leer = alle Klassen). rows: Zeilen der Tabelle (Tests geben eigene).
static func extras_between(class_id: StringName, p_previous: int, p_level: int, rows: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row: TableRow in rows:
		if not _row_matches(row, class_id):
			continue
		var at := int(row.get_value("stufe", 0))
		if at > p_previous and at <= p_level:
			result.append({"id": StringName(str(row.get_value("id", ""))), "text": str(row.get_value("text", "")),
					"window": StringName(str(row.get_value("fenster", "")))})
	return result


## true, wenn eine Freischaltung aus stufenfreischaltungen.csv für die Klasse
## auf dieser Stufe gilt (für spätere Systeme, z. B. Reittier).
static func has_unlock(unlock_id: StringName, class_id: StringName, p_level: int, rows: Array = []) -> bool:
	if rows.is_empty():
		rows = Data.rows(UNLOCK_TABLE)
	for row: TableRow in rows:
		if StringName(str(row.get_value("id", ""))) == unlock_id and _row_matches(row, class_id):
			return p_level >= int(row.get_value("stufe", 0))
	return false


static func _row_matches(row: TableRow, class_id: StringName) -> bool:
	var row_class := StringName(str(row.get_value("klasse", "")))
	return row_class == &"" or row_class == class_id


## „Ausdauer +3, Stärke +2, …“ (leer, wenn nichts gestiegen ist).
func stat_text() -> String:
	var parts: PackedStringArray = []
	for gain in stat_gains:
		parts.append("%s %+d" % [gain["name"], int(gain["value"])])
	return ", ".join(parts)


## Hinweis zu Talentpunkten oder leer.
func talent_text() -> String:
	if talent_points <= 0:
		return ""
	if talent_points == 1:
		return "Du hast einen Talentpunkt erhalten."
	return "Du hast %d Talentpunkte erhalten." % talent_points


## Alle Zeilen als Text (Log, Tests), ohne Überschrift.
func lines() -> PackedStringArray:
	var result: PackedStringArray = []
	if stat_text() != "":
		result.append(stat_text())
	for ability in abilities:
		result.append("Neue Fähigkeit: %s" % ability.display_name)
	if talent_text() != "":
		result.append(talent_text())
	if spec_unlocked:
		result.append("Du kannst jetzt eine Spezialisierung wählen.")
	for extra in extras:
		result.append(str(extra["text"]))
	return result


func title() -> String:
	return "Stufe %d erreicht!" % level
