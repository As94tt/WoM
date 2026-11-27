class_name ItemDataCheck
extends RefCounted
## Datenprüfung der Ausrüstung (Ticket #29), aufgerufen von DataSet.load_all,
## sobald alle Tabellen einzeln fehlerfrei sind. Arbeitet direkt auf dem
## DataSet (der Autoload „Data“ ist dabei noch nicht fertig).
##
## Fehler (der Stand ist ungültig):
## - Ausrüstung ohne Slot bzw. Slot bei anderen Gegenständen
## - keine passende Zeile in slotzuordnung.csv (slot + handhabung)
## - Waffe ohne Waffentyp, Waffentyp passt nicht zum Slot, Waffentyp bei
##   Nicht-Waffen
## - Rüstungsteil ohne Rüstungsklasse, Rüstungsklasse bei anderen Plätzen
## - Ausrüstung mit Stapelgröße über 1
## - Aura in „effekte“ nicht versteckt, beendbar oder nicht dauerhaft, oder
##   von einem zweiten Gegenstand genutzt (die Quelle der Aura ist der
##   Gegenstand; zwei Gegenstände würden sich beim Ablegen stören)
## Warnungen (der Stand bleibt gültig): leere Rüstung bei Rüstungsteilen und
## Schilden, leerer Waffenschaden bei Waffen – beides zählt 0, die Berechnung
## folgt mit #71.

const TABLE := "gegenstaende"
const EQUIPMENT_TYPE := "ausruestung"
const AURA_DIR := "res://data/auras/"


static func check(data_set: DataSet) -> void:
	var file := "%s.csv" % TABLE
	var aura_users: Dictionary = {}  # Aura-ID → Gegenstand
	for row: TableRow in data_set.get_rows(TABLE):
		var slot := str(row.get_value("slot", ""))
		var is_equipment := str(row.get_value("typ", "")) == EQUIPMENT_TYPE
		if not is_equipment:
			if slot != "":
				data_set.add_error(file, row.line, "slot", "Slot nur bei Ausrüstung.")
			continue
		if slot == "":
			data_set.add_error(file, row.line, "slot", "Ausrüstung ohne Slot.")
			continue
		var hand := str(row.get_value("handhabung", ""))
		var mapping := _mapping(data_set, slot, hand)
		if mapping == null:
			data_set.add_error(file, row.line, "handhabung",
					"Keine Zeile in slotzuordnung.csv für Slot ‚%s‘ mit Handhabung ‚%s‘." % [slot, hand])
			continue
		if int(row.get_value("stapelgroesse", 1)) != 1:
			data_set.add_error(file, row.line, "stapelgroesse", "Ausrüstung muss Stapelgröße 1 haben.")
		_check_weapon(data_set, row, mapping, slot)
		_check_armor(data_set, row, mapping)
		_check_auras(data_set, row, aura_users)


## Zeile der Slotzuordnung (erst mit Handhabung, dann ohne).
static func _mapping(data_set: DataSet, slot: String, hand: String) -> TableRow:
	if hand != "":
		var exact := data_set.get_row("slotzuordnung", [slot, hand])
		if exact != null:
			return exact
	return data_set.get_row("slotzuordnung", [slot, ""])


static func _check_weapon(data_set: DataSet, row: TableRow, mapping: TableRow, slot: String) -> void:
	var file := "%s.csv" % TABLE
	var allowed: Array = mapping.get_value("waffentypen", [])
	var weapon_type := str(row.get_value("waffentyp", ""))
	if allowed.is_empty():
		if weapon_type != "":
			data_set.add_error(file, row.line, "waffentyp", "Waffentyp nur bei Waffen, Schilden und Fokussen.")
		return
	if weapon_type == "":
		data_set.add_error(file, row.line, "waffentyp", "Waffe ohne Waffentyp.")
		return
	if not allowed.has(weapon_type):
		data_set.add_error(file, row.line, "waffentyp",
				"Waffentyp ‚%s‘ passt nicht zum Slot ‚%s‘ (erlaubt: %s)." % [weapon_type, slot, ", ".join(allowed)])
		return
	var type_row := data_set.get_row("waffentypen", weapon_type)
	var deals_damage := type_row != null and str(type_row.get_value("handhabung", "")) != "nebenhand"
	if deals_damage and (row.is_blank("schaden_min") or row.is_blank("schaden_max")):
		data_set.add_warning(file, row.line, "schaden_min", "Waffenschaden leer, zählt 0 (Berechnung folgt mit #71).")
	if weapon_type == "schild" and row.is_blank("ruestung"):
		data_set.add_warning(file, row.line, "ruestung", "Rüstung des Schilds leer, zählt 0.")


static func _check_armor(data_set: DataSet, row: TableRow, mapping: TableRow) -> void:
	var file := "%s.csv" % TABLE
	var armor_class := str(row.get_value("ruestungsklasse", ""))
	if bool(mapping.get_value("ruestungsklasse_noetig", false)):
		if armor_class == "":
			data_set.add_error(file, row.line, "ruestungsklasse", "Rüstungsteil ohne Rüstungsklasse.")
		if row.is_blank("ruestung"):
			data_set.add_warning(file, row.line, "ruestung", "Rüstung leer, zählt 0 (Berechnung folgt mit #71).")
	elif armor_class != "":
		data_set.add_error(file, row.line, "ruestungsklasse",
				"Rüstungsklasse nur bei Rüstungsteilen (Helm bis Armschienen).")


static func _check_auras(data_set: DataSet, row: TableRow, aura_users: Dictionary) -> void:
	var file := "%s.csv" % TABLE
	for aura_id: Variant in row.get_value("effekte", []):
		var id := str(aura_id)
		if aura_users.has(id):
			data_set.add_error(file, row.line, "effekte",
					"Aura ‚%s‘ nutzt schon ‚%s‘; jede Aura gehört zu genau einem Gegenstand." % [id, aura_users[id]])
			continue
		aura_users[id] = row.id()
		var path := AURA_DIR.path_join(id + ".tres")
		var aura := load(path) as AuraData if ResourceLoader.exists(path) else null
		if aura == null:
			continue  # Fehlender Verweis ist schon gemeldet (Spalte effekte).
		if not aura.hidden or aura.cancelable or aura.duration > 0.0 or aura.ability_id != &"":
			data_set.add_error(file, row.line, "effekte",
					"Aura ‚%s‘ eines Gegenstands muss versteckt, nicht beendbar und dauerhaft sein." % id)
