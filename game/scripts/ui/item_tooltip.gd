class_name ItemTooltip
extends RefCounted
## Tooltip eines Gegenstands (Ticket #18) im Taschenfenster und in der
## Taschenleiste: Name in der Seltenheitsfarbe (RarityColors), darunter
## Seltenheit und Typ als Text (zweites Signal neben der Farbe), bei Taschen
## die Plätze, Beschreibung, Stapel und Verkaufswert.
## Aussehen nur über Theme-Variationen; die Namensfarbe wird zur Laufzeit
## aus dem Theme gesetzt (wie die Klassenfarbe).

const DESCRIPTION_WIDTH := 280.0


## Inhalt für Control._make_custom_tooltip(). count = Anzahl auf dem Platz
## (0 = ohne Stapelzeile, z. B. angelegte Tasche).
static func create(id: StringName, count := 0) -> Control:
	var box := VBoxContainer.new()
	box.theme_type_variation = &"SlotColumn"
	var title := _label(ItemInfo.display_name(id), &"Subtitle")
	title.add_theme_color_override(&"font_color", ItemInfo.rarity_color(id))
	box.add_child(title)
	for line in _lines(id, count):
		var variation := &"BodyText" if line == ItemInfo.description(id) else &"SmallLabel"
		var label := _label(line, variation)
		if variation == &"BodyText":
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.custom_minimum_size.x = DESCRIPTION_WIDTH
		box.add_child(label)
	return box


## Derselbe Inhalt als Text (tooltip_text, Tests, Fallback).
static func text(id: StringName, count := 0) -> String:
	var lines: PackedStringArray = [ItemInfo.display_name(id)]
	lines.append_array(_lines(id, count))
	return "\n".join(lines)


## Zeilen unter dem Namen.
static func _lines(id: StringName, count: int) -> PackedStringArray:
	var lines: PackedStringArray = ["%s · %s" % [ItemInfo.rarity_name(id), ItemInfo.type_name(id)]]
	if ItemInfo.is_bag(id):
		lines.append("Tasche mit %d Plätzen" % ItemInfo.bag_slots(id))
	if ItemInfo.description(id) != "":
		lines.append(ItemInfo.description(id))
	var stack := ItemInfo.stack_size(id)
	if count > 0 and stack > 1:
		lines.append("Stapel: %d / %d" % [count, stack])
	var value := ItemInfo.sell_value(id)
	if value > 0:
		var total := value * maxi(1, count)
		var value_text := "Verkaufswert: %s" % ItemInfo.money_text(value)
		if count > 1:
			value_text += " (Stapel: %s)" % ItemInfo.money_text(total)
		lines.append(value_text)
	else:
		lines.append("Kein Verkaufswert")
	return lines


static func _label(content: String, variation: StringName) -> Label:
	var label := Label.new()
	label.theme_type_variation = variation
	label.text = content
	return label
