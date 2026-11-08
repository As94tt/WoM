class_name TalentTreeData
extends Resource
## Talentbaum einer Spezialisierung (Ticket #20): Reihen von oben nach unten.
## Anzahl der Reihen, Schwellen und Talentarten sind pro Baum frei wählbar.
## Datensätze liegen in res://data/talents/.

@export var rows: Array[TalentRowData] = []


## Talent zur ID oder null.
func get_talent(talent_id: StringName) -> TalentData:
	for row in rows:
		if row == null:
			continue
		for talent in row.talents:
			if talent != null and talent.id == talent_id:
				return talent
	return null


## Index der Reihe eines Talents oder −1.
func row_index_of(talent_id: StringName) -> int:
	for index in rows.size():
		var row := rows[index]
		if row == null:
			continue
		for talent in row.talents:
			if talent != null and talent.id == talent_id:
				return index
	return -1


func get_row_of(talent_id: StringName) -> TalentRowData:
	var index := row_index_of(talent_id)
	return rows[index] if index >= 0 else null


## Alle Talente in Reihenfolge der Reihen.
func get_all_talents() -> Array[TalentData]:
	var result: Array[TalentData] = []
	for row in rows:
		if row == null:
			continue
		for talent in row.talents:
			if talent != null:
				result.append(talent)
	return result


## Alle Fähigkeiten, die Talente dieses Baums geben können.
func get_all_granted_abilities() -> Array[AbilityData]:
	var result: Array[AbilityData] = []
	for talent in get_all_talents():
		for ability in talent.grants_abilities:
			if ability != null and not result.has(ability):
				result.append(ability)
	return result


## Datenfehler als Text (leer = in Ordnung): doppelte oder leere IDs, zu
## wenige/viele Talente in Wahl-Reihen, unbekannte Voraussetzungen. Geprüft
## von den Tests (--tests) für alle Klassen.
func get_problems() -> PackedStringArray:
	var problems: PackedStringArray = []
	var seen := {}
	for index in rows.size():
		var row := rows[index]
		if row == null:
			problems.append("Reihe %d fehlt." % (index + 1))
			continue
		if row.is_choice() and (row.talents.size() < 2 or row.talents.size() > 3):
			problems.append("Reihe %d: Wahl braucht 2–3 Talente." % (index + 1))
		if not row.is_choice() and row.talents.is_empty():
			problems.append("Reihe %d hat keine Talente." % (index + 1))
		for talent in row.talents:
			if talent == null or talent.id == &"":
				problems.append("Reihe %d: Talent ohne ID." % (index + 1))
				continue
			if seen.has(talent.id):
				problems.append("Talent-ID %s gibt es doppelt." % talent.id)
			seen[talent.id] = true
	for talent in get_all_talents():
		if talent.requires != &"" and get_talent(talent.requires) == null:
			problems.append("%s: Voraussetzung %s gibt es nicht." % [talent.id, talent.requires])
	return problems
