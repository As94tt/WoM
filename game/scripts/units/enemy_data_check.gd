class_name EnemyDataCheck
extends RefCounted
## Datenprüfung der Spawngruppen (Ticket #36), aufgerufen von
## DataSet.load_all, sobald alle Tabellen einzeln fehlerfrei sind (wie
## ItemDataCheck). Arbeitet direkt auf dem DataSet.
##
## Fehler (der Stand ist ungültig):
## - stufe_min größer als stufe_max
## - selten_chance oder selten_zeit_* gesetzt, aber kein selten_gegner
## - nur eine der beiden Zeiten selten_zeit_min_s/selten_zeit_max_s gesetzt,
##   oder die kleinste größer als die größte
## Warnungen (der Stand bleibt gültig):
## - selten_gegner ohne Chance und ohne Zeit (erscheint nie)
## - Stufe ohne Zeile in gegner_stufenwerte.csv (es gilt die höchste
##   vorhandene darunter, siehe Enemy.level_row)

const TABLE := "spawngruppen"


static func check(data_set: DataSet) -> void:
	var file := "%s.csv" % TABLE
	var levels: Dictionary = {}
	for row: TableRow in data_set.get_rows("gegner_stufenwerte"):
		levels[int(row.get_value("stufe", 0))] = true
	for row: TableRow in data_set.get_rows(TABLE):
		var low := int(row.get_value("stufe_min", 1))
		var high := int(row.get_value("stufe_max", 1))
		if low > high:
			data_set.add_error(file, row.line, "stufe_min", "stufe_min (%d) ist größer als stufe_max (%d)." % [low, high])
			continue
		var rare := str(row.get_value("selten_gegner", ""))
		var chance := float(row.get_value("selten_chance", 0.0))
		var time_min := float(row.get_value("selten_zeit_min_s", 0.0))
		var time_max := float(row.get_value("selten_zeit_max_s", 0.0))
		if rare == "" and (chance > 0.0 or time_min > 0.0 or time_max > 0.0):
			data_set.add_error(file, row.line, "selten_gegner", "Chance oder Zeit für seltene Gegner ohne selten_gegner.")
		if (time_min > 0.0) != (time_max > 0.0):
			data_set.add_error(file, row.line, "selten_zeit_min_s",
					"selten_zeit_min_s und selten_zeit_max_s nur zusammen nutzen (oder beide 0).")
		elif time_min > time_max:
			data_set.add_error(file, row.line, "selten_zeit_min_s", "selten_zeit_min_s ist größer als selten_zeit_max_s.")
		if rare != "" and chance <= 0.0 and time_min <= 0.0:
			data_set.add_warning(file, row.line, "selten_gegner",
					"Seltener Gegner ohne selten_chance und ohne selten_zeit_* erscheint nie.")
		var wanted: Array[int] = []
		for level in range(low, high + 1):
			wanted.append(level)
		var rare_level := int(row.get_value("selten_stufe", 0))
		if rare != "" and rare_level > 0:
			wanted.append(rare_level)
		for level in wanted:
			if not levels.has(level):
				data_set.add_warning(file, row.line, "stufe_max",
						"Stufe %d fehlt in gegner_stufenwerte.csv, es gilt die höchste darunter." % level)
				break
