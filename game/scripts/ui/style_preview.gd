extends Control
## Vorschauszene für das zentrale UI-Theme (Ticket #10, erweitert in #6, #8, #17, #15, #30, #21, #31 und #32).
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
	_add_combat_samples()
	_add_casting_samples()

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


## Auren und Kampftext (#32): Buff, Debuffs je Kategorie (AuraBuff,
## AuraDebuff*), Stapelzahl, Restzeit (AuraText) und die Kampftext-Arten.
func _add_combat_samples() -> void:
	var grid: GridContainer = $ScrollContainer/MarginContainer/Content/HudGrid
	_add_row(grid, "Aura-Symbole: Buff (AuraBuff), Debuffs ohne Kategorie, Magie, Gift, Krankheit, Fluch, körperlich (AuraDebuff*), Stapel und Restzeit (AuraText)")
	var row := HFlowContainer.new()
	row.theme_type_variation = &"AuraFlow"
	grid.add_child(row)
	var samples: Array[Array] = [[false, AuraData.Category.MAGIC, 1], [true, AuraData.Category.NONE, 1],
			[true, AuraData.Category.MAGIC, 3], [true, AuraData.Category.POISON, 1],
			[true, AuraData.Category.DISEASE, 1], [true, AuraData.Category.CURSE, 1],
			[true, AuraData.Category.PHYSICAL, 5]]
	for sample in samples:
		var data := AuraData.new()
		data.id = &"vorschau"
		data.display_name = "Vorschau Aura"
		data.is_debuff = sample[0]
		data.category = sample[1]
		data.duration = 12.0
		var inst := AuraInstance.new()
		inst.data = data
		inst.stacks = sample[2]
		inst.expires_at = Network.host_time() + 12.0
		var icon: AuraIcon = preload("res://scenes/ui/hud/aura_icon.tscn").instantiate()
		row.add_child(icon)
		icon.setup(inst, null, 36)
	_add_row(grid, "Kampftext: Schaden (CombatTextDamage), Heilung (CombatTextHeal), erlittener Schaden (CombatTextTaken), Immun/Absorbiert (CombatTextInfo)")
	var texts := HBoxContainer.new()
	texts.theme_type_variation = &"ButtonRow"
	grid.add_child(texts)
	for kind: Combat.TextKind in CombatTextLayer.VARIATIONS:
		var label := Label.new()
		label.theme_type_variation = CombatTextLayer.VARIATIONS[kind]
		label.text = CombatTextLayer.text_for(kind, 1234.0)
		texts.add_child(label)


## Fähigkeiten wirken (#33): Aktionsslots mit Abklingzeit, Proc-Leuchten,
## aktivem Umschalter, Tönungen (außer Reichweite, Ressource fehlt),
## Aufladungen; Zauberleisten (füllen, kanalisieren, nicht unterbrechbar,
## fertig, unterbrochen); Fehlermeldung; Schulfarben.
func _add_casting_samples() -> void:
	var grid: GridContainer = $ScrollContainer/MarginContainer/Content/HudGrid
	var ability := GameData.get_ability(&"test_meteor")
	_add_row(grid, "Aktionsslots: Abklingzeit (CooldownSweep, SlotCooldownText), Proc (SlotProcGlow), aktiv (SlotActive), außer Reichweite, Ressource fehlt (AbilityColors), Aufladungen")
	var slots := HBoxContainer.new()
	slots.theme_type_variation = &"SlotRow"
	grid.add_child(slots)
	var states: Array[Dictionary] = [
		{"cooldown": Vector2(7.0, 10.0)},
		{"gcd": Vector2(0.6, 1.5)},
		{"highlight": true},
		{"active": true},
		{"out_of_range": true},
		{"no_resource": true},
		{"charges": 2},
	]
	for state in states:
		var slot: ActionSlot = preload("res://scenes/ui/hud/action_slot.tscn").instantiate()
		slots.add_child(slot)
		if ability != null:
			slot.show_content(ActionSlotContent.ability(ability.id), true)
		slot.update_state(state)
	_add_row(grid, "Zauberleisten: Zauberzeit (CastBar), kanalisiert (CastBarChannel), nicht unterbrechbar (Schild), fertig (CastBarDone), unterbrochen (CastBarFailed)")
	var bars := VBoxContainer.new()
	bars.theme_type_variation = &"SlotColumn"
	bars.custom_minimum_size = Vector2(360, 0)
	grid.add_child(bars)
	var samples := [[&"CastBar", "Testblitz  1,2 s", 0.6, false], [&"CastBarChannel", "Testkanal  2,0 s", 0.66, false],
			[&"CastBar", "Puppenschild  2,4 s", 0.2, true], [&"CastBarDone", "Testblitz", 1.0, false],
			[&"CastBarFailed", "Testblitz – Unterbrochen", 1.0, false]]
	for sample: Array in samples:
		var bar: CastBar = preload("res://scenes/ui/hud/cast_bar.tscn").instantiate()
		bars.add_child(bar)
		bar.set_process(false)
		bar.visible = true
		bar.get_node("%Shield").visible = sample[3]
		var progress: ProgressBar = bar.get_node("%Bar")
		progress.theme_type_variation = sample[0]
		progress.max_value = 1.0
		progress.value = sample[2]
		bar.get_node("%Text").text = sample[1]
	_add_row(grid, "Fehlermeldung oben in der Mitte (ErrorMessage)")
	var error := Label.new()
	error.theme_type_variation = &"ErrorMessage"
	error.text = AbilityError.text(AbilityError.Code.NO_RESOURCE, "mana")
	grid.add_child(error)
	_add_row(grid, "Schulfarben (SchoolColors): Projektile, Leuchten beim Zaubern")
	var schools := HFlowContainer.new()
	schools.theme_type_variation = &"AuraFlow"
	grid.add_child(schools)
	for row in Data.schadensschulen():
		var label := Label.new()
		label.theme_type_variation = &"SmallLabel"
		label.text = "● " + String(row.get_value("name", ""))
		label.add_theme_color_override("font_color", CombatColors.school_color(StringName(str(row.get_value("id", "")))))
		schools.add_child(label)
