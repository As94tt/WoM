extends Control
## Vorschauszene für das zentrale UI-Theme (Ticket #10, erweitert in #6, #8, #17, #15, #30, #21 und #31).
## Zeigt alle Button-Zustände gleichzeitig. Hover lässt sich nicht statisch
## erzwingen, deshalb bekommen die Hover-Beispiele die Hover-Werte aus dem
## Theme als Normalzustand. Es werden keine eigenen Farben gesetzt, nur Werte
## aus theme.tres übernommen. Rein lokal, keine Netzwerkfunktion.


func _ready() -> void:
	var hover_button: Button = %HoverButton
	hover_button.add_theme_stylebox_override("normal", hover_button.get_theme_stylebox("hover"))
	hover_button.add_theme_color_override("font_color", hover_button.get_theme_color("font_hover_color"))

	# Listeneinträge der Charakterauswahl (#6) mit einem Beispielcharakter.
	# Volk und Klasse kommen aus den Daten, die Klassenfarbe aus ClassData.
	var sample := CharacterData.new()
	sample.character_name = "Durgin"
	sample.level = 12
	var races := GameData.get_races()
	var classes := GameData.get_classes()
	if not races.is_empty():
		sample.race_id = races[0].id
	if not classes.is_empty():
		sample.class_id = classes[0].id
	for entry: CharacterEntry in [%EntryNormal, %EntryHover, %EntrySelected, %EntryDisabled]:
		entry.setup(sample)
	%EntryHover.add_theme_stylebox_override("normal", %EntryHover.get_theme_stylebox("hover"))

	# Auswahlbutton der Charaktererstellung (#8), Hover dauerhaft dargestellt.
	var choice_hover: Button = %ChoiceHover
	choice_hover.add_theme_stylebox_override("normal", choice_hover.get_theme_stylebox("hover"))
	choice_hover.add_theme_color_override("font_color", choice_hover.get_theme_color("font_hover_color"))

	# Interface im Spiel (#17): Aktionsslots mit Hover, Aufleuchten und Taste.
	%SlotHover.add_theme_stylebox_override("normal", %SlotHover.get_theme_stylebox("hover"))
	%SlotFlashing.get_node("%Flash").visible = true
	%SlotKey.input_action = &"action_bar_1_slot_1"

	# Mitspieler auf der Karte (#30): Klassenfarbe aus den Daten.
	if not classes.is_empty():
		%MateMarker.fill_color = classes[0].color

	_add_spellbook_samples()
	_add_unit_samples()

	%FocusButton.grab_focus()


## Zauberbuch und Aktionsleisten (#21): Einträge (erlernt, passiv, nicht
## erlernt), Slots mit Fähigkeit (normal, ausgegraut) und der Tooltip.
func _add_spellbook_samples() -> void:
	var grid: GridContainer = $ScrollContainer/MarginContainer/Content/HudGrid
	var feuerball := GameData.get_ability(&"feuerball")
	var passive := GameData.get_ability(&"passiv_magier")
	var gegenzauber := GameData.get_ability(&"gegenzauber")
	if feuerball == null or passive == null or gegenzauber == null:
		return
	_add_row(grid, "Zauberbuch-Eintrag: erlernt, passiv, nicht erlernt (HintText, SmallHintText)")
	var entries := VBoxContainer.new()
	entries.theme_type_variation = &"SpellbookGrid"
	entries.custom_minimum_size.x = 218
	grid.add_child(entries)
	for ability in [feuerball, passive, gegenzauber]:
		var entry: SpellbookEntry = preload("res://scenes/ui/hud/spellbook_entry.tscn").instantiate()
		entries.add_child(entry)
		# Ohne Figur (null) gilt learned_without_player.
		entry.setup(ability, null, ability != gegenzauber)

	_add_row(grid, "Aktionsslot mit Fähigkeit: normal, ausgegraut (nicht erlernt)")
	var slots := HBoxContainer.new()
	slots.theme_type_variation = &"SlotRow"
	grid.add_child(slots)
	for learned in [true, false]:
		var slot: ActionSlot = preload("res://scenes/ui/hud/action_slot.tscn").instantiate()
		slots.add_child(slot)
		slot.show_content(ActionSlotContent.ability(feuerball.id), learned)

	_add_row(grid, "Tooltip einer Fähigkeit (Subtitle, SmallLabel, BodyText, HintText)")
	var tooltip := PanelContainer.new()
	tooltip.theme_type_variation = &"TooltipPanel"
	tooltip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tooltip.add_child(AbilityTooltip.create(gegenzauber, false))
	grid.add_child(tooltip)


func _add_row(grid: GridContainer, text: String) -> void:
	var label := Label.new()
	label.theme_type_variation = &"SmallLabel"
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 240
	grid.add_child(label)


## Einheiten (#31): Bestandteile von Spieler- und Zielrahmen und der
## Namensplaketten. Farben kommen aus dem Theme (UnitColors, *Bar).
func _add_unit_samples() -> void:
	var grid: GridContainer = $ScrollContainer/MarginContainer/Content/HudGrid
	_add_row(grid, "Rahmen-Bestandteile: Lebens- und Ressourcenbalken (HealthBar, ManaBar, RageBar, EnergyBar, ChiBar, Text BarText)")
	var bars := VBoxContainer.new()
	bars.theme_type_variation = &"SlotColumn"
	bars.custom_minimum_size.x = 260
	grid.add_child(bars)
	for entry: Array in [[&"HealthBar", "1.250 / 2.000", 0.62], [&"ManaBar", "415 / 415", 1.0],
			[&"RageBar", "40 / 100", 0.4], [&"EnergyBar", "80 / 100", 0.8], [&"ChiBar", "25 / 100", 0.25]]:
		var bar := ProgressBar.new()
		bar.theme_type_variation = entry[0]
		bar.show_percentage = false
		bar.custom_minimum_size.y = 22
		bar.value = entry[2] * 100.0
		var text := Label.new()
		text.theme_type_variation = &"BarText"
		text.text = entry[1]
		text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		bar.add_child(text)
		bars.add_child(bar)

	_add_row(grid, "Gesinnung (UnitColors: hostile, neutral, friendly) und Stufenunterschied (level_*), Kennzeichen (UnitBadge)")
	var colors := VBoxContainer.new()
	colors.theme_type_variation = &"SlotColumn"
	grid.add_child(colors)
	var reactions := HBoxContainer.new()
	reactions.theme_type_variation = &"InlineRow"
	colors.add_child(reactions)
	for reaction: Unit.Reaction in UnitColors.REACTION_NAMES:
		var label := Label.new()
		label.theme_type_variation = &"BodyText"
		label.text = UnitColors.REACTION_NAMES[reaction]
		label.add_theme_color_override("font_color", UnitColors.reaction_color(reaction))
		reactions.add_child(label)
	var levels := HBoxContainer.new()
	levels.theme_type_variation = &"InlineRow"
	colors.add_child(levels)
	for difficulty: UnitColors.Difficulty in UnitColors.DIFFICULTY_NAMES:
		var label := Label.new()
		label.theme_type_variation = &"SmallLabel"
		label.text = UnitColors.DIFFICULTY_NAMES[difficulty]
		label.add_theme_color_override("font_color", UnitColors.difficulty_color(difficulty))
		levels.add_child(label)
	var badges := HBoxContainer.new()
	badges.theme_type_variation = &"InlineRow"
	colors.add_child(badges)
	for text: String in ["Elite", "Selten", "Boss", "Im Kampf"]:
		var badge := PanelContainer.new()
		badge.theme_type_variation = &"UnitBadge"
		var label := Label.new()
		label.theme_type_variation = &"SmallLabel"
		label.text = text
		badge.add_child(label)
		badges.add_child(badge)

	_add_row(grid, "Namensplakette: normal (NameplatePanel) und Ziel (NameplateTargetPanel), Text NameplateText")
	var plates := HBoxContainer.new()
	plates.theme_type_variation = &"ButtonRow"
	grid.add_child(plates)
	for variation: StringName in [&"NameplatePanel", &"NameplateTargetPanel"]:
		var panel := PanelContainer.new()
		panel.theme_type_variation = variation
		var column := VBoxContainer.new()
		column.theme_type_variation = &"NameplateColumn"
		panel.add_child(column)
		var plate_name := Label.new()
		plate_name.theme_type_variation = &"NameplateText"
		plate_name.text = "Schadenspuppe"
		plate_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plate_name.add_theme_color_override("font_color", UnitColors.reaction_color(Unit.Reaction.HOSTILE))
		column.add_child(plate_name)
		var row := HBoxContainer.new()
		row.theme_type_variation = &"InlineRow"
		column.add_child(row)
		var level := Label.new()
		level.theme_type_variation = &"NameplateText"
		level.text = "10"
		row.add_child(level)
		var bar := ProgressBar.new()
		bar.theme_type_variation = &"HealthBar"
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(120, 8)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.value = 70.0
		row.add_child(bar)
		plates.add_child(panel)
