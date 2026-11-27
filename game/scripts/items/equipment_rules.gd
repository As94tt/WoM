class_name EquipmentRules
extends RefCounted
## Regeln der Ausrüstung (Ticket #29) als reine Logik ohne Knoten (testbar).
## Alles Inhaltliche kommt aus den Tabellen (über „Data“):
## - slotzuordnung.csv: welche Gegenstandsart in welche Plätze passt,
##   Zweihand, Nebenhand nur bei Beidhändigkeit, Rüstungsteile, Siegel und
##   Talisman immer „Einzigartig angelegt“
## - klassenausruestung.csv: höchste Rüstungsklasse (leichtere gehen auch,
##   Rang aus ruestungsklassen.csv), Waffentypen, Beidhändigkeit je Klasse
## - ausruestungsplaetze.csv: Plätze und welche im Kampf wechselbar sind
##   (Waffen: Haupthand, Nebenhand, Fernkampf)
## - gegenstaende.csv: Mindeststufe, Klassen, Einzigartig (angelegt), Werte
##
## Zustand der Ausrüstung (equipment_state): {Platz-ID: Gegenstands-ID} als
## Strings, nur belegte Plätze. Eine Zweihandwaffe steht nur in der Haupthand
## und lässt die Nebenhand leer (belegt sie aber).

## Spalte in gegenstaende.csv → Wert-ID im Wertesystem (StatRules).
const STAT_COLUMNS := {
	"staerke": &"strength",
	"gewandtheit": &"agility",
	"intellekt": &"intellect",
	"ausdauer": &"stamina",
	"willenskraft": &"willpower",
	"praezision": &"precision",
	"verheerung": &"devastation",
	"tempo": &"haste",
	"durchschlag": &"penetration",
	"abwehr": &"avoidance",
	"eile": &"swiftness",
	"ruestung": &"armor",
	"zauberschutz": &"spell_ward",
	"blockwert": &"block_value",
}
## Attribute (Tooltip: weiße Zeilen „+12 Stärke“).
const ATTRIBUTE_COLUMNS: Array[String] = ["staerke", "gewandtheit", "intellekt", "ausdauer", "willenskraft"]
## Wertungen (Tooltip: grüne Zeilen „Anlegen: +8 Präzision“).
const RATING_COLUMNS: Array[String] = ["praezision", "verheerung", "tempo", "durchschlag", "abwehr", "eile"]
## Verteidigung (Tooltip: oben bei Rüstung bzw. Blockwert).
const DEFENSE_COLUMNS: Array[String] = ["ruestung", "zauberschutz", "blockwert"]

const MAIN_HAND := &"haupthand"
const OFF_HAND := &"nebenhand"
const RANGED := &"fernkampf"

const MSG_NOT_EQUIPMENT := "Das lässt sich nicht anlegen."
const MSG_WRONG_PLACE := "Das passt nicht in diesen Platz."
const MSG_CLASS := "Eure Klasse kann das nicht tragen."
const MSG_LEVEL := "Benötigt Stufe %d."
const MSG_DUAL_WIELD := "Ihr könnt nicht mit zwei Waffen kämpfen."
const MSG_UNIQUE_EQUIPPED := "Ihr könnt nur einen davon gleichzeitig angelegt haben."
const MSG_COMBAT := "Im Kampf nicht möglich."
const MSG_NOT_READY := "Noch nicht bereit."
const MSG_DEAD := "Im Tod nicht möglich."
const MSG_EMPTY := "Dort ist nichts angelegt."


# --- Plätze und Zuordnung ----------------------------------------------------

## Alle Ausrüstungsplätze in Tabellenreihenfolge.
static func all_places() -> Array[StringName]:
	var result: Array[StringName] = []
	for r in Data.ausruestungsplaetze():
		result.append(StringName(r.id()))
	return result


## Anzeigename eines Platzes („Ring 1“).
static func place_name(place: StringName) -> String:
	var r := Data.ausruestungsplatz(place)
	return str(r.get_value("name", place)) if r != null else String(place)


## Waffenplatz: im Kampf wechselbar (Haupthand, Nebenhand, Fernkampf).
static func is_weapon_place(place: StringName) -> bool:
	var r := Data.ausruestungsplatz(place)
	return r != null and bool(r.get_value("im_kampf_wechselbar", false))


## Plätze, in die der Gegenstand passt (leer = keine Ausrüstung).
static func places_for(item_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	var mapping := ItemInfo.slot_mapping(item_id)
	if mapping != null:
		for place: Variant in mapping.get_value("plaetze", []):
			result.append(StringName(str(place)))
	return result


## Belegt Haupt- und Nebenhand (Zweihandwaffe).
static func occupies_both_hands(item_id: StringName) -> bool:
	var mapping := ItemInfo.slot_mapping(item_id)
	return mapping != null and bool(mapping.get_value("belegt_beide_haende", false))


static func _offhand_needs_dual_wield(item_id: StringName) -> bool:
	var mapping := ItemInfo.slot_mapping(item_id)
	return mapping != null and bool(mapping.get_value("nebenhand_nur_beidhaendig", false))


# --- Klasse ------------------------------------------------------------------

## Klasse darf zwei Einhandwaffen führen.
static func can_dual_wield(class_id: StringName) -> bool:
	var r := Data.klassenausruestung(class_id)
	return r != null and bool(r.get_value("beidhaendig", false))


## Warum die Klasse den Gegenstand nicht tragen darf ("" = darf):
## Klassenliste, Rüstungsklasse (höchste erlaubte und leichtere), Waffentyp.
static func class_reason(item_id: StringName, class_id: StringName) -> String:
	var classes := ItemInfo.class_ids(item_id)
	if not classes.is_empty() and not classes.has(class_id):
		return MSG_CLASS
	var rules := Data.klassenausruestung(class_id)
	var armor := ItemInfo.armor_class(item_id)
	if armor != &"":
		var allowed := Data.ruestungsklasse(StringName(str(rules.get_value("ruestungsklasse", "")))) \
				if rules != null else null
		var wanted := Data.ruestungsklasse(armor)
		if allowed == null or wanted == null \
				or int(wanted.get_value("rang", 99)) > int(allowed.get_value("rang", 0)):
			return MSG_CLASS
	var weapon := ItemInfo.weapon_type(item_id)
	if weapon != &"":
		var types: Array = rules.get_value("waffentypen", []) if rules != null else []
		if not types.has(String(weapon)):
			return MSG_CLASS
	return ""


## Warum der Charakter den Gegenstand überhaupt nicht nutzen kann ("" =
## nutzbar): keine Ausrüstung, Klasse, Mindeststufe, Nebenhand-Waffe ohne
## Beidhändigkeit. Grundlage für den roten Schleier in der Tasche.
static func usable_reason(item_id: StringName, class_id: StringName, level: int) -> String:
	if not ItemInfo.is_equipment(item_id) or places_for(item_id).is_empty():
		return MSG_NOT_EQUIPMENT
	var reason := class_reason(item_id, class_id)
	if reason != "":
		return reason
	if ItemInfo.required_level(item_id) > level:
		return MSG_LEVEL % ItemInfo.required_level(item_id)
	var places := places_for(item_id)
	if places.size() == 1 and places[0] == OFF_HAND and _offhand_needs_dual_wield(item_id) \
			and not can_dual_wield(class_id):
		return MSG_DUAL_WIELD
	return ""


# --- Anlegen und Ablegen -----------------------------------------------------

## Platz für Rechtsklick: der erste freie erlaubte, sonst der erste erlaubte.
## Die Nebenhand zählt nur, wenn die Klasse sie für diesen Gegenstand nutzen
## darf (Beidhändigkeit).
static func choose_place(item_id: StringName, state: Dictionary, class_id: StringName) -> StringName:
	var candidates: Array[StringName] = []
	for place in places_for(item_id):
		if place == OFF_HAND and _offhand_needs_dual_wield(item_id) and not can_dual_wield(class_id):
			continue
		candidates.append(place)
	if candidates.is_empty():
		var all := places_for(item_id)
		return all[0] if not all.is_empty() else &""
	for place in candidates:
		if not state.has(String(place)) and not (place == OFF_HAND and _two_hander_in_main(state)):
			return place
	return candidates[0]


## Prüft das Anlegen von item_id in place. Ergebnis:
## {ok: bool, reason: String, displaced: {Platz: Gegenstand}, state: neuer Zustand}.
## displaced = Gegenstände, die dabei in die Tasche wandern (bisheriger Inhalt
## des Platzes; bei Zweihand auch die Nebenhand; ein Nebenhand-Gegenstand
## verdrängt eine Zweihandwaffe).
static func check_equip(item_id: StringName, place: StringName, state: Dictionary, class_id: StringName,
		level: int, in_combat := false, busy := false) -> Dictionary:
	var result := {"ok": false, "reason": "", "displaced": {}, "state": state}
	if not ItemInfo.is_equipment(item_id):
		result["reason"] = MSG_NOT_EQUIPMENT
		return result
	if not places_for(item_id).has(place):
		result["reason"] = MSG_WRONG_PLACE
		return result
	var reason := class_reason(item_id, class_id)
	if reason == "" and ItemInfo.required_level(item_id) > level:
		reason = MSG_LEVEL % ItemInfo.required_level(item_id)
	if reason == "" and place == OFF_HAND and _offhand_needs_dual_wield(item_id) and not can_dual_wield(class_id):
		reason = MSG_DUAL_WIELD
	if reason != "":
		result["reason"] = reason
		return result
	var displaced := {}
	var key := String(place)
	if state.has(key):
		displaced[key] = str(state[key])
	if occupies_both_hands(item_id) and state.has(String(OFF_HAND)):
		displaced[String(OFF_HAND)] = str(state[String(OFF_HAND)])
	if place == OFF_HAND and _two_hander_in_main(state):
		displaced[String(MAIN_HAND)] = str(state[String(MAIN_HAND)])
	# Einzigartig angelegt: derselbe Gegenstand in einem anderen Platz, der bleibt.
	if ItemInfo.is_unique_equipped(item_id):
		for other: String in state:
			if other != key and not displaced.has(other) and str(state[other]) == String(item_id):
				result["reason"] = MSG_UNIQUE_EQUIPPED
				return result
	if in_combat:
		if not is_weapon_place(place):
			result["reason"] = MSG_COMBAT
			return result
		for other: String in displaced:
			if not is_weapon_place(StringName(other)):
				result["reason"] = MSG_COMBAT
				return result
		if busy:
			result["reason"] = MSG_NOT_READY
			return result
	var new_state := state.duplicate()
	for other: String in displaced:
		new_state.erase(other)
	new_state[key] = String(item_id)
	result["ok"] = true
	result["displaced"] = displaced
	result["state"] = new_state
	return result


## Prüft das Ablegen. Ergebnis: {ok, reason, item, state}.
static func check_unequip(place: StringName, state: Dictionary, in_combat := false, busy := false) -> Dictionary:
	var result := {"ok": false, "reason": "", "item": "", "state": state}
	var key := String(place)
	if not state.has(key):
		result["reason"] = MSG_EMPTY
		return result
	if in_combat:
		if not is_weapon_place(place):
			result["reason"] = MSG_COMBAT
			return result
		if busy:
			result["reason"] = MSG_NOT_READY
			return result
	var new_state := state.duplicate()
	new_state.erase(key)
	result["ok"] = true
	result["item"] = str(state[key])
	result["state"] = new_state
	return result


## Bereinigt einen mitgebrachten Stand (Beitreten): unbekannte Plätze und
## Gegenstände, falsche Plätze, Klasse, Mindeststufe, Einzigartig angelegt
## und Konflikte (Zweihand und Nebenhand) fallen heraus.
## Ergebnis: {state: Dictionary, removed: [[Platz, Gegenstand, Grund], …]}.
static func sanitize(data: Variant, class_id: StringName, level: int) -> Dictionary:
	var state := {}
	var removed: Array = []
	if not data is Dictionary:
		return {"state": state, "removed": removed}
	var places := all_places()
	for key: Variant in (data as Dictionary).keys():
		if not places.has(StringName(str(key))):
			removed.append([str(key), str(data[key]), "Unbekannter Platz."])
	for place in places:
		var key := String(place)
		if not (data as Dictionary).has(key):
			continue
		var item_id := StringName(str(data[key]))
		if not ItemInfo.exists(item_id):
			removed.append([key, String(item_id), "Unbekannter Gegenstand."])
			continue
		var check := check_equip(item_id, place, state, class_id, level)
		if not bool(check["ok"]):
			removed.append([key, String(item_id), str(check["reason"])])
		elif not (check["displaced"] as Dictionary).is_empty():
			removed.append([key, String(item_id), "Der Platz ist schon belegt."])
		else:
			state = check["state"]
	return {"state": state, "removed": removed}


static func _two_hander_in_main(state: Dictionary) -> bool:
	var main := StringName(str(state.get(String(MAIN_HAND), "")))
	return main != &"" and occupies_both_hands(main)


# --- Werte -------------------------------------------------------------------

## Durchschnittliche Gegenstandsstufe der angelegten Gegenstände (leere
## Plätze zählen nicht, eine Zweihandwaffe einmal); 0 ohne Ausrüstung.
static func average_item_level(state: Dictionary) -> float:
	var total := 0
	var count := 0
	for place: String in state:
		var item_id := StringName(str(state[place]))
		if ItemInfo.exists(item_id):
			total += ItemInfo.item_level(item_id)
			count += 1
	return float(total) / count if count > 0 else 0.0


## Werte eines Gegenstands: Wert-ID → Zahl (ohne Nullen).
static func stat_values(item_id: StringName) -> Dictionary:
	var result := {}
	for column: String in STAT_COLUMNS:
		var value := ItemInfo.number(item_id, column)
		if value != 0:
			result[STAT_COLUMNS[column]] = value
	return result


## Modifikatoren eines angelegten Gegenstands (Quelle „item:ID:PLATZ“).
static func modifiers_for(item_id: StringName, place: StringName) -> Array[StatModifier]:
	var result: Array[StatModifier] = []
	var source := source_of(item_id, place)
	var item_name := ItemInfo.display_name(item_id)
	var values := stat_values(item_id)
	for stat: StringName in values:
		result.append(StatModifier.create(source, item_name, stat, float(values[stat])))
	return result


## Quelle der Werte und Auren eines angelegten Gegenstands.
static func source_of(item_id: StringName, place: StringName) -> StringName:
	return StringName("item:%s:%s" % [item_id, place])


## Zustände für die Waffen aus der Ausrüstung: {melee, shield, offhand, ranged}.
static func weapon_flags(state: Dictionary) -> Dictionary:
	var main := StringName(str(state.get(String(MAIN_HAND), "")))
	var off := StringName(str(state.get(String(OFF_HAND), "")))
	return {
		"melee": main != &"" and ItemInfo.is_damage_weapon(main),
		"shield": off != &"" and ItemInfo.weapon_type(off) == &"schild",
		"offhand": off != &"" and ItemInfo.is_damage_weapon(off),
		"ranged": state.has(String(RANGED)),
	}


## Waffenwerte eines Gegenstands als Zeile mit den Feldern von
## platzhalterwaffen.csv (tempo, schaden_min, schaden_max, reichweite, name),
## damit Combat.weapon_damage und der automatische Angriff sie wie bisher
## lesen. null, wenn der Gegenstand keine Waffe mit Schaden ist.
static func weapon_row(item_id: StringName) -> TableRow:
	if item_id == &"" or not ItemInfo.is_damage_weapon(item_id):
		return null
	var r := TableRow.new()
	r.table = "gegenstaende"
	r.values = {
		"id": String(item_id),
		"name": ItemInfo.display_name(item_id),
		"tempo": ItemInfo.weapon_speed(item_id),
		"schaden_min": float(ItemInfo.number(item_id, "schaden_min")),
		"schaden_max": float(ItemInfo.number(item_id, "schaden_max")),
		"reichweite": ItemInfo.weapon_range(item_id),
	}
	return r
