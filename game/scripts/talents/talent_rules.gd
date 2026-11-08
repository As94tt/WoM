class_name TalentRules
extends RefCounted
## Regeln des Talentsystems (Ticket #20) als reine Funktionen: Punkte,
## freigeschaltete Reihen, Punkt vergeben und zurücknehmen, Prüfung eines
## ganzen Stands. Kein Zustand, keine Knoten; geprüft mit „--tests“
## (test_talents.gd). PlayerTalents (Host) und das Talentfenster (Anzeige,
## vorläufige Änderungen) nutzen dieselben Funktionen.
##
## Ränge stehen in einem Dictionary „Talent-ID (String) → Rang (int)“; Talente
## ohne Punkt fehlen darin. Eine Reihe ist frei, wenn in den Reihen darüber
## mindestens TalentRowData.required_points Punkte ausgegeben sind.
##
## Zahlen (spielkonstanten.csv): spezialisierung_ab_stufe (10),
## talentpunkt_ab_stufe (11, erster Punkt), talentpunkte_je_stufe (1).

# --- Zahlen aus den Daten ----------------------------------------------------

## Stufe, ab der eine Spezialisierung gewählt werden kann.
static func spec_level() -> int:
	return int(Data.konstante(&"spezialisierung_ab_stufe", 10.0))


## Stufe, auf der es den ersten Talentpunkt gibt.
static func first_point_level() -> int:
	return int(Data.konstante(&"talentpunkt_ab_stufe", 11.0))


static func points_per_level() -> int:
	return int(Data.konstante(&"talentpunkte_je_stufe", 1.0))


## Talentpunkte insgesamt auf dieser Stufe plus Bonuspunkte (Entwickler-Panel).
static func total_points(level: int, bonus := 0) -> int:
	return points_for_level(level, first_point_level(), points_per_level()) + maxi(0, bonus)


# --- Reine Formeln -----------------------------------------------------------

## Punkte aus der Stufe: ab first_level je Stufe per_level Punkte
## (Stufe 30 mit 11/1 = 20 Punkte).
static func points_for_level(level: int, first_level: int, per_level: int) -> int:
	return maxi(0, level - first_level + 1) * maxi(0, per_level)


## Ausgegebene Punkte.
static func spent(ranks: Dictionary) -> int:
	var total := 0
	for key: Variant in ranks:
		total += maxi(0, int(ranks[key]))
	return total


static func rank_of(ranks: Dictionary, talent_id: StringName) -> int:
	return maxi(0, int(ranks.get(String(talent_id), 0)))


## Punkte in den Reihen über row_index.
static func points_above(tree: TalentTreeData, ranks: Dictionary, row_index: int) -> int:
	var total := 0
	for index in mini(row_index, tree.rows.size()):
		total += points_in_row(tree, ranks, index)
	return total


static func points_in_row(tree: TalentTreeData, ranks: Dictionary, row_index: int) -> int:
	var row := tree.rows[row_index]
	var total := 0
	if row != null:
		for talent in row.talents:
			if talent != null:
				total += rank_of(ranks, talent.id)
	return total


static func is_row_unlocked(tree: TalentTreeData, ranks: Dictionary, row_index: int) -> bool:
	if row_index < 0 or row_index >= tree.rows.size() or tree.rows[row_index] == null:
		return false
	return points_above(tree, ranks, row_index) >= tree.rows[row_index].required_points


## Warum kein Punkt auf talent_id vergeben werden kann (leer = geht).
## total = alle Punkte (total_points).
static func add_reason(tree: TalentTreeData, ranks: Dictionary, talent_id: StringName, total: int) -> String:
	var row_index := tree.row_index_of(talent_id)
	if row_index < 0:
		return "Unbekanntes Talent."
	var row := tree.rows[row_index]
	var talent := tree.get_talent(talent_id)
	var rank := rank_of(ranks, talent_id)
	if rank >= row.max_rank_of(talent):
		return "Höchster Rang erreicht."
	if row.is_choice():
		for other in row.talents:
			if other != null and other != talent and rank_of(ranks, other.id) > 0:
				return "In dieser Reihe ist schon „%s“ gewählt." % other.display_name
	if not is_row_unlocked(tree, ranks, row_index):
		return "Erfordert %d Punkte in den Reihen darüber." % row.required_points
	if talent.requires != &"":
		var required := tree.get_talent(talent.requires)
		if required != null and rank_of(ranks, required.id) < tree.get_row_of(required.id).max_rank_of(required):
			return "Erfordert „%s“ (voll gelernt)." % required.display_name
	if spent(ranks) >= total:
		return "Keine Talentpunkte frei."
	return ""


## Warum talent_id keinen Punkt abgeben kann (leer = geht): kein Punkt
## vergeben, eine tiefere Reihe verlöre ihre Schwelle oder ein anderes
## gelerntes Talent setzt es voraus.
static func remove_reason(tree: TalentTreeData, ranks: Dictionary, talent_id: StringName) -> String:
	var row_index := tree.row_index_of(talent_id)
	if row_index < 0:
		return "Unbekanntes Talent."
	if rank_of(ranks, talent_id) <= 0:
		return "Kein Punkt vergeben."
	var after := with_removed(ranks, talent_id)
	for index in range(row_index + 1, tree.rows.size()):
		if points_in_row(tree, after, index) > 0 and not is_row_unlocked(tree, after, index):
			return "Punkt wird für eine tiefere Reihe benötigt."
	for other in tree.get_all_talents():
		if other.requires == talent_id and rank_of(after, other.id) > 0:
			return "„%s“ setzt dieses Talent voraus." % other.display_name
	return ""


## Kopie mit einem Punkt mehr auf talent_id (ohne Prüfung).
static func with_added(ranks: Dictionary, talent_id: StringName) -> Dictionary:
	var result := ranks.duplicate()
	result[String(talent_id)] = rank_of(ranks, talent_id) + 1
	return result


## Kopie mit einem Punkt weniger (Talente mit 0 fallen heraus).
static func with_removed(ranks: Dictionary, talent_id: StringName) -> Dictionary:
	var result := ranks.duplicate()
	var rank := rank_of(ranks, talent_id) - 1
	if rank > 0:
		result[String(talent_id)] = rank
	else:
		result.erase(String(talent_id))
	return result


## Prüft einen ganzen Stand (leer = gültig): nur Talente des Baums, Ränge im
## Rahmen, höchstens ein Talent je Wahl-Reihe, Schwellen und Voraussetzungen
## erfüllt, nicht mehr Punkte als total. total < 0 = Punkte nicht prüfen.
static func validate(tree: TalentTreeData, ranks: Dictionary, total: int) -> String:
	if tree == null:
		return "Kein Talentbaum." if not ranks.is_empty() else ""
	for key: Variant in ranks:
		var talent := tree.get_talent(StringName(str(key)))
		if talent == null:
			return "Unbekanntes Talent „%s“." % key
		var rank := int(ranks[key])
		if rank < 1 or rank > tree.get_row_of(talent.id).max_rank_of(talent):
			return "Ungültiger Rang bei „%s“." % talent.display_name
		if talent.requires != &"":
			var required := tree.get_talent(talent.requires)
			if required != null and rank_of(ranks, required.id) < tree.get_row_of(required.id).max_rank_of(required):
				return "„%s“ erfordert „%s“." % [talent.display_name, required.display_name]
	for index in tree.rows.size():
		var row := tree.rows[index]
		if row == null:
			continue
		var used := 0
		for talent in row.talents:
			if talent != null and rank_of(ranks, talent.id) > 0:
				used += 1
		if row.is_choice() and used > 1:
			return "In Reihe %d ist mehr als ein Talent gewählt." % (index + 1)
		if used > 0 and not is_row_unlocked(tree, ranks, index):
			return "Reihe %d ist noch nicht frei." % (index + 1)
	if total >= 0 and spent(ranks) > total:
		return "Nicht genug Talentpunkte."
	return ""


## Nur einfache Typen, Talente mit Rang ≥ 1 (für Speichern und Übertragung).
static func clean_ranks(data: Variant) -> Dictionary:
	var result := {}
	if data is Dictionary:
		for key: Variant in data:
			var rank := int(data[key]) if (data[key] is int or data[key] is float) else 0
			if rank > 0 and str(key) != "":
				result[str(key)] = rank
	return result
