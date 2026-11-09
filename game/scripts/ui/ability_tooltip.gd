class_name AbilityTooltip
extends RefCounted
## Tooltip einer Fähigkeit (Ticket #21), gleich im Zauberbuch und auf den
## Aktionsleisten. Aktive Fähigkeiten: Name, Kosten und Reichweite, Zauberart
## und Abklingzeit, Beschreibung. Passive: Name, „Passiv“, Beschreibung.
## Nicht erlernte zusätzlich „Erfordert Stufe X“.
##
## Die Zahlen kommen aus faehigkeitswerte.csv (AbilityData.get_cost() usw.),
## Aussehen nur über Theme-Variationen (TooltipPanel kommt vom Tooltip selbst).
## Seit #20 optional mit caster: Dann stehen die Zahlen mit allen
## Veränderungen durch Talente da (AbilityData.get_number_for).

## Breite der Beschreibung, damit lange Texte umbrechen.
const DESCRIPTION_WIDTH := 320.0
const RULES: StatRules = preload("res://data/stats/stat_rules.tres")


## Inhalt für Control._make_custom_tooltip().
static func create(ability: AbilityData, learned: bool, caster: Unit = null) -> Control:
	var box := VBoxContainer.new()
	box.theme_type_variation = &"SlotColumn"
	box.add_child(_label(ability.display_name, &"Subtitle"))
	if ability.passive:
		box.add_child(_label("Passiv", &"SmallLabel"))
	else:
		for pair in _value_rows(ability, caster):
			if pair[0] == "" and pair[1] == "":
				continue
			var row := HBoxContainer.new()
			row.theme_type_variation = &"InlineRow"
			var left := _label(pair[0], &"SmallLabel")
			left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(left)
			var right := _label(pair[1], &"SmallLabel")
			right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			row.add_child(right)
			box.add_child(row)
	if ability.description != "":
		var description := _label(ability.description, &"BodyText")
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.custom_minimum_size.x = DESCRIPTION_WIDTH
		box.add_child(description)
	if not learned:
		box.add_child(_label(required_level_text(ability), &"HintText"))
	return box


## Derselbe Inhalt als Text (tooltip_text, z. B. für Tests und als Fallback).
static func text(ability: AbilityData, learned: bool, caster: Unit = null) -> String:
	var lines: PackedStringArray = [ability.display_name]
	if ability.passive:
		lines.append("Passiv")
	else:
		for pair in _value_rows(ability, caster):
			var parts: PackedStringArray = []
			for part: String in pair:
				if part != "":
					parts.append(part)
			if not parts.is_empty():
				lines.append(" · ".join(parts))
	if ability.description != "":
		lines.append(ability.description)
	if not learned:
		lines.append(required_level_text(ability))
	return "\n".join(lines)


static func required_level_text(ability: AbilityData) -> String:
	return "Erfordert Stufe %d" % ability.required_level


## Kosten, z. B. „30 Mana“; leer ohne Kosten.
static func cost_text(ability: AbilityData, caster: Unit = null) -> String:
	var cost := ability.get_number_for(caster, "kosten")
	var resource_id := ability.get_cost_resource()
	if cost <= 0.0 or resource_id == &"":
		return ""
	return "%s %s" % [_number(cost), RULES.get_resource_name(resource_id)]


## Reichweite, z. B. „30 m Reichweite“; 0 = „Nahkampfreichweite“.
static func range_text(ability: AbilityData, caster: Unit = null) -> String:
	var distance := ability.get_number_for(caster, "reichweite")
	if distance <= 0.0:
		return "Nahkampfreichweite"
	return "%s m Reichweite" % _number(distance)


## Zauberart: „Sofort“, „2,5 Sek. Zauberzeit“ oder „Kanalisiert (4 Sek.)“.
static func cast_text(ability: AbilityData, caster: Unit = null) -> String:
	# Mit Veränderungen (#22: z. B. „nächster Meteor sofort wirkbar“).
	var channel := ability.get_number_for(caster, "kanalisierzeit")
	if channel > 0.0:
		return "Kanalisiert (%s Sek.)" % _number(channel)
	var cast := ability.get_number_for(caster, "zauberzeit")
	if cast > 0.0:
		return "%s Sek. Zauberzeit" % _number(cast)
	return "Sofort"


## Abklingzeit, z. B. „20 Sek. Abklingzeit“; leer ohne Abklingzeit.
static func cooldown_text(ability: AbilityData, caster: Unit = null) -> String:
	var cooldown := ability.get_number_for(caster, "abklingzeit")
	if cooldown <= 0.0:
		return ""
	if cooldown >= 60.0 and is_equal_approx(fmod(cooldown, 60.0), 0.0):
		return "%s Min. Abklingzeit" % _number(cooldown / 60.0)
	return "%s Sek. Abklingzeit" % _number(cooldown)


## Schadensschule eines Zaubers (#22), z. B. „Schule: Feuer“; leer bei
## körperlichen Fähigkeiten.
static func school_text(ability: AbilityData) -> String:
	if not ability.is_spell:
		return ""
	return "Schule: %s" % Data.schulname(ability.get_school())


## Zeilen links/rechts: [Kosten, Reichweite], [Zauberart, Abklingzeit],
## [Schule].
static func _value_rows(ability: AbilityData, caster: Unit = null) -> Array:
	return [
		[cost_text(ability, caster), range_text(ability, caster)],
		[cast_text(ability, caster), cooldown_text(ability, caster)],
		[school_text(ability), ""],
	]


## Zahl ohne überflüssige Nachkommastellen, deutsches Komma („2,5“, „30“).
static func _number(value: float) -> String:
	var whole := is_equal_approx(value, roundf(value))
	return StatFormat.number(value, 0 if whole else 1)


static func _label(content: String, variation: StringName) -> Label:
	var label := Label.new()
	label.theme_type_variation = variation
	label.text = content
	return label
