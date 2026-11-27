class_name ItemTooltip
extends RefCounted
## Tooltip eines Gegenstands (Ticket #18, Ausrüstung seit #29) im
## Taschenfenster, in der Taschenleiste und im Charakterfenster.
##
## Andere Gegenstände: Name in der Seltenheitsfarbe (RarityColors), darunter
## „Seltenheit · Typ“ als Text (zweites Signal neben der Farbe), bei Taschen die
## Plätze, Beschreibung, Stapel und Verkaufswert.
##
## Ausrüstung (#29, von oben nach unten):
##  1. Name in der Seltenheitsfarbe, darunter die Seltenheit als Text
##  2. Bindung, „Einzigartig“, „Einzigartig angelegt“
##  3. Slot links, Typ rechts („Brust“ … „Platte“, „Einhand“ … „Schwert“)
##  4. Rüstung, Zauberschutz, Blockwert bzw. Waffenschaden, Tempo und Schaden
##     pro Sekunde
##  5. Attribute („+12 Stärke“)
##  6. Wertungen grün („Anlegen: +8 Präzision“, ItemColors/stat)
##  7. Effekte grün (Beschreibung der Aura, „Anlegen: …“, „Treffer: …“)
##  8. Beschreibung
##  9. „Benötigt Stufe X“ und Klasseneinschränkung, rot wenn nicht erfüllt
##     (ItemColors/requirement_missing); ebenso der Typ, wenn die Klasse ihn
##     nicht tragen darf
## 10. Gegenstandsstufe, Verkaufswert
## 11. Herkunftstext in Goldschrift (ItemColors/origin)
## Vergleich (compare, nur Tasche): daneben der Tooltip der angelegten
## Gegenstände, die ersetzt würden (bei Ringen und Talismanen alle angelegten),
## und am neuen Gegenstand „Beim Anlegen:“ mit den Unterschieden („+5 Stärke“
## in StatBonus, „−3 Ausdauer“ in StatMalus; zweites Signal ist das Vorzeichen).
##
## Aussehen nur über Theme-Variationen und Theme-Farben (RarityColors,
## ItemColors); Farben werden zur Laufzeit aus dem Theme gesetzt (wie die
## Klassenfarbe), nie im Code festgelegt.

const DESCRIPTION_WIDTH := 280.0
const COLOR_TYPE := &"ItemColors"
const COLOR_STAT := &"stat"
const COLOR_ORIGIN := &"origin"
const COLOR_MISSING := &"requirement_missing"
const RULES: StatRules = preload("res://data/stats/stat_rules.tres")
## Plätze, bei denen der Vergleich alle angelegten Gegenstände zeigt.
const COMPARE_ALL_SLOTS: Array[StringName] = [&"ring", &"talisman"]


## Inhalt für Control._make_custom_tooltip(). count = Anzahl auf dem Platz
## (0 = ohne Stapelzeile, z. B. angelegte Tasche). context = Ausrüstung des
## eigenen Charakters (Klasse, Stufe, Vergleich) oder null. compare = daneben
## die angelegten Gegenstände zeigen (Tasche).
static func create(id: StringName, count := 0, context: PlayerEquipment = null, compare := false) -> Control:
	var compared: Array[StringName] = []
	if compare:
		compared = compared_items(id, context)
	var main := _build(id, count, context, compared)
	if compared.is_empty():
		return main
	var row := HBoxContainer.new()
	row.theme_type_variation = &"InlineRow"
	row.add_child(main)
	for other: StringName in compared:
		var panel := PanelContainer.new()
		panel.theme_type_variation = &"TooltipPanel"
		var box := _build(other, 0, context, [])
		var header := _label("Angelegt", &"HintText")
		box.add_child(header)
		box.move_child(header, 0)
		panel.add_child(box)
		row.add_child(panel)
	return row


## Derselbe Inhalt als Text (tooltip_text, Tests, Fallback).
static func text(id: StringName, count := 0, context: PlayerEquipment = null, compare := false) -> String:
	var lines: PackedStringArray = []
	var compared: Array[StringName] = []
	if compare:
		compared = compared_items(id, context)
	for entry in entries(id, count, context, compared):
		var line := str(entry["text"])
		if str(entry.get("right", "")) != "":
			line += "  " + str(entry["right"])
		lines.append(line)
	return "\n".join(lines)


## Angelegte Gegenstände für den Vergleich: die, die beim Anlegen ersetzt
## würden; bei Ringen und Talismanen alle angelegten dieser Art.
static func compared_items(id: StringName, context: PlayerEquipment) -> Array[StringName]:
	var result: Array[StringName] = []
	if context == null or not ItemInfo.is_equipment(id):
		return result
	if COMPARE_ALL_SLOTS.has(ItemInfo.slot(id)):
		for place in EquipmentRules.places_for(id):
			if context.has_item(place):
				result.append(context.get_item(place))
		return result
	var place := context.choose_place(id)
	var replaced := context.get_replaced(id, place)
	for key: String in replaced:
		result.append(StringName(str(replaced[key])))
	return result


## Farbe aus dem Theme-Typ ItemColors (z. B. &"stat"); ohne Eintrag die
## normale Schriftfarbe.
static func item_color(key: StringName) -> Color:
	var theme := ThemeDB.get_project_theme()
	if theme != null and theme.has_color(key, COLOR_TYPE):
		return theme.get_color(key, COLOR_TYPE)
	if theme != null and theme.has_color(&"font_color", &"Label"):
		return theme.get_color(&"font_color", &"Label")
	return ThemeDB.get_default_theme().get_color(&"font_color", &"Label")


# --- Aufbau ------------------------------------------------------------------

static func _build(id: StringName, count: int, context: PlayerEquipment, compared: Array) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.theme_type_variation = &"SlotColumn"
	for entry in entries(id, count, context, compared):
		box.add_child(_make_row(entry, id))
	return box


static func _make_row(entry: Dictionary, id: StringName) -> Control:
	var label := _label(str(entry["text"]), entry.get("variation", &"SmallLabel"))
	var color := StringName(str(entry.get("color", "")))
	if color == &"rarity":
		label.add_theme_color_override(&"font_color", ItemInfo.rarity_color(id))
	elif color != &"":
		label.add_theme_color_override(&"font_color", item_color(color))
	if bool(entry.get("wrap", false)):
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = DESCRIPTION_WIDTH
	var right_text := str(entry.get("right", ""))
	if right_text == "":
		return label
	var row := HBoxContainer.new()
	row.theme_type_variation = &"InlineRow"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var right := _label(right_text, entry.get("variation", &"SmallLabel"))
	right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var right_color := StringName(str(entry.get("right_color", "")))
	if right_color != &"":
		right.add_theme_color_override(&"font_color", item_color(right_color))
	row.add_child(right)
	return row


## Alle Zeilen als {text, variation, color, right, right_color, wrap}.
## color: &"rarity", ein Name aus ItemColors oder leer.
static func entries(id: StringName, count := 0, context: PlayerEquipment = null, compared: Array = []) -> Array[Dictionary]:
	var result: Array[Dictionary] = [_entry(ItemInfo.display_name(id), &"Subtitle", &"rarity")]
	if not ItemInfo.is_equipment(id):
		result.append(_entry("%s · %s" % [ItemInfo.rarity_name(id), ItemInfo.type_name(id)]))
		if ItemInfo.is_bag(id):
			result.append(_entry("Tasche mit %d Plätzen" % ItemInfo.bag_slots(id)))
		if ItemInfo.description(id) != "":
			result.append(_entry(ItemInfo.description(id), &"BodyText", &"", true))
		var stack := ItemInfo.stack_size(id)
		if count > 0 and stack > 1:
			result.append(_entry("Stapel: %d / %d" % [count, stack]))
		result.append(_entry(_value_text(id, count)))
		return result
	result.append(_entry(ItemInfo.rarity_name(id)))
	if ItemInfo.binding_text(id) != "":
		result.append(_entry(ItemInfo.binding_text(id)))
	if ItemInfo.is_unique(id):
		result.append(_entry("Einzigartig"))
	if ItemInfo.is_unique_equipped(id):
		result.append(_entry("Einzigartig angelegt"))
	var class_id := context.get_class_id() if context != null else &""
	var kind_blocked := context != null and ItemInfo.class_ids(id).is_empty() \
			and EquipmentRules.class_reason(id, class_id) != ""
	var slot_entry := _entry(ItemInfo.slot_text(id))
	slot_entry["right"] = ItemInfo.kind_text(id)
	if kind_blocked:
		slot_entry["right_color"] = COLOR_MISSING
	result.append(slot_entry)
	# Verteidigung bzw. Waffe
	if ItemInfo.is_damage_weapon(id):
		var damage := _entry("%d – %d Schaden" % [ItemInfo.number(id, "schaden_min"), ItemInfo.number(id, "schaden_max")],
				&"BodyText")
		damage["right"] = "Tempo %s" % StatFormat.number(ItemInfo.weapon_speed(id), 2)
		result.append(damage)
		result.append(_entry("(%s Schaden pro Sekunde)" % StatFormat.number(ItemInfo.dps(id), 1), &"BodyText"))
	for column: String in EquipmentRules.DEFENSE_COLUMNS:
		var value := ItemInfo.number(id, column)
		if value != 0:
			result.append(_entry("%s %s" % [StatFormat.grouped(value), _stat_name(column)], &"BodyText"))
	for column: String in EquipmentRules.ATTRIBUTE_COLUMNS:
		var value := ItemInfo.number(id, column)
		if value != 0:
			result.append(_entry("%s %s" % [_signed(value), _stat_name(column)], &"BodyText"))
	for column: String in EquipmentRules.RATING_COLUMNS:
		var value := ItemInfo.number(id, column)
		if value != 0:
			result.append(_entry("Anlegen: %s %s" % [_signed(value), _stat_name(column)], &"BodyText", COLOR_STAT))
	for aura in ItemInfo.effect_auras(id):
		result.append(_entry(aura.description, &"BodyText", COLOR_STAT, true))
	if ItemInfo.description(id) != "":
		result.append(_entry(ItemInfo.description(id), &"BodyText", &"", true))
	var required := ItemInfo.required_level(id)
	if required > 1:
		var low := context != null and context.get_level() < required
		result.append(_entry("Benötigt Stufe %d" % required, &"SmallLabel", COLOR_MISSING if low else &""))
	var classes := ItemInfo.class_ids(id)
	if not classes.is_empty():
		var names: PackedStringArray = []
		for c in classes:
			var data := GameData.get_class_data(c)
			names.append(data.display_name if data != null else String(c))
		var blocked := context != null and not classes.has(class_id)
		result.append(_entry("Klassen: %s" % ", ".join(names), &"SmallLabel", COLOR_MISSING if blocked else &""))
	result.append(_entry("Gegenstandsstufe %d" % ItemInfo.item_level(id)))
	result.append(_entry(_value_text(id, 0)))
	if ItemInfo.origin(id) != "":
		result.append(_entry("„%s“" % ItemInfo.origin(id), &"BodyText", COLOR_ORIGIN, true))
	if context != null and not compared.is_empty():
		result.append_array(_compare_entries(id, compared))
	return result


## „Beim Anlegen:“ und je Wert der Unterschied zu den ersetzten Gegenständen.
static func _compare_entries(id: StringName, compared: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var lines: Array[Dictionary] = []
	if ItemInfo.is_damage_weapon(id) or _any_weapon(compared):
		var old_dps := 0.0
		for other: StringName in compared:
			old_dps += ItemInfo.dps(other)
		var diff_dps := ItemInfo.dps(id) - old_dps
		if absf(diff_dps) >= 0.05:
			lines.append(_diff_entry(diff_dps, "Schaden pro Sekunde", 1))
	var columns: Array[String] = []
	columns.append_array(EquipmentRules.DEFENSE_COLUMNS)
	columns.append_array(EquipmentRules.ATTRIBUTE_COLUMNS)
	columns.append_array(EquipmentRules.RATING_COLUMNS)
	for column: String in columns:
		var diff := ItemInfo.number(id, column)
		for other: StringName in compared:
			diff -= ItemInfo.number(other, column)
		if diff != 0:
			lines.append(_diff_entry(diff, _stat_name(column), 0))
	if lines.is_empty():
		return result
	result.append(_entry("Beim Anlegen:", &"SmallLabel"))
	result.append_array(lines)
	return result


static func _any_weapon(items: Array) -> bool:
	for other: StringName in items:
		if ItemInfo.is_damage_weapon(other):
			return true
	return false


static func _diff_entry(diff: float, label_text: String, decimals: int) -> Dictionary:
	var sign_text := "+" if diff > 0.0 else StatFormat.MINUS
	return _entry("%s%s %s" % [sign_text, StatFormat.number(absf(diff), decimals), label_text],
			&"StatBonus" if diff > 0.0 else &"StatMalus")


static func _entry(content: String, variation: StringName = &"SmallLabel", color: StringName = &"",
		wrap := false) -> Dictionary:
	return {"text": content, "variation": variation, "color": color, "wrap": wrap}


static func _signed(value: int) -> String:
	return ("+%d" % value) if value >= 0 else "%s%d" % [StatFormat.MINUS, -value]


## Anzeigename eines Werts aus dem Wertesystem („Stärke“, „Rüstung“).
static func _stat_name(column: String) -> String:
	var definition := RULES.get_stat(EquipmentRules.STAT_COLUMNS.get(column, &""))
	return definition.display_name if definition != null else column


static func _value_text(id: StringName, count: int) -> String:
	var value := ItemInfo.sell_value(id)
	if value <= 0:
		return "Kein Verkaufswert"
	var value_text := "Verkaufswert: %s" % ItemInfo.money_text(value)
	if count > 1:
		value_text += " (Stapel: %s)" % ItemInfo.money_text(value * count)
	return value_text


static func _label(content: String, variation: StringName) -> Label:
	var label := Label.new()
	label.theme_type_variation = variation
	label.text = content
	return label
